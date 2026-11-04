// Command ont-photos stores the app's user photos (custom meals, recipes,
// progress photos) for accounts, so another device of the same account can
// show them. The app encrypts every photo on the device before uploading it
// (AES-GCM under a key derived from the account data key) and names it with
// a keyed hash, so this service only ever sees opaque ids and ciphertext.
//
// It runs inside the web image next to nginx, which proxies /photos-api/ to
// it on the loopback interface (nginx.app.conf).
//
//	GET    /photos-api/v1/          list: {"photos": {"<id>": "<etag>"}}
//	PUT    /photos-api/v1/<id>      store the request body (at most maxPhotoBytes)
//	GET    /photos-api/v1/<id>      the stored bytes
//	HEAD   /photos-api/v1/<id>      headers only
//	DELETE /photos-api/v1/<id>      remove (204 also when it was missing)
//
// Every request needs `Authorization: Bearer <Supabase access token>`. The
// token is checked against <SUPABASE_URL>/auth/v1/user and storage is scoped
// to the user it belongs to: <PHOTOS_DIR>/<user id>/<id>.
package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	apiPrefix        = "/photos-api/v1/"
	maxPhotoBytes    = 4 << 20
	maxPhotosPerUser = 20000
	maxTokenLength   = 8192
	tokenCacheTTL    = 60 * time.Second
	maxCacheEntries  = 4096
	tempPrefix       = ".upload-"
)

var (
	// A photo id is a hex HMAC-SHA256: nothing else can name a file, which
	// rules out path traversal and hidden or temporary files.
	photoIDPattern = regexp.MustCompile(`^[0-9a-f]{64}$`)
	// Supabase Auth user ids are UUIDs; anything else is refused before it
	// becomes a directory name.
	userIDPattern = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)
)

var (
	errUnauthorized  = errors.New("token refused")
	errNotConfigured = errors.New("auth not configured")
	errUpstream      = errors.New("auth service unavailable")
)

// Authenticator maps a bearer token to the id of the user it belongs to.
type Authenticator interface {
	UserID(ctx context.Context, token string) (string, error)
}

type cacheEntry struct {
	userID  string
	expires time.Time
}

// SupabaseAuth validates tokens with GET <baseURL>/auth/v1/user and keeps
// the answer for valid ones for ttl, keyed by the SHA-256 of the token (the
// token itself is never stored or logged). Refused tokens are not cached.
type SupabaseAuth struct {
	baseURL string
	anonKey string
	client  *http.Client
	ttl     time.Duration
	now     func() time.Time

	mu    sync.Mutex
	cache map[[32]byte]cacheEntry
}

func NewSupabaseAuth(baseURL, anonKey string, client *http.Client) *SupabaseAuth {
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	return &SupabaseAuth{
		baseURL: strings.TrimRight(baseURL, "/"),
		anonKey: anonKey,
		client:  client,
		ttl:     tokenCacheTTL,
		now:     time.Now,
		cache:   map[[32]byte]cacheEntry{},
	}
}

func (a *SupabaseAuth) UserID(ctx context.Context, token string) (string, error) {
	key := sha256.Sum256([]byte(token))
	now := a.now()
	a.mu.Lock()
	if e, ok := a.cache[key]; ok {
		if now.Before(e.expires) {
			a.mu.Unlock()
			return e.userID, nil
		}
		delete(a.cache, key)
	}
	a.mu.Unlock()

	if a.baseURL == "" || a.anonKey == "" {
		return "", errNotConfigured
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.baseURL+"/auth/v1/user", nil)
	if err != nil {
		return "", errNotConfigured
	}
	req.Header.Set("apikey", a.anonKey)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := a.client.Do(req)
	if err != nil {
		return "", errUpstream
	}
	defer resp.Body.Close()
	switch resp.StatusCode {
	case http.StatusOK:
	case http.StatusBadRequest, http.StatusUnauthorized, http.StatusForbidden, http.StatusNotFound:
		// 404: the token is well formed but its user no longer exists.
		return "", errUnauthorized
	default:
		return "", errUpstream
	}
	var body struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&body); err != nil {
		return "", errUpstream
	}
	userID := strings.ToLower(body.ID)
	if !userIDPattern.MatchString(userID) {
		return "", errUpstream
	}

	a.mu.Lock()
	if len(a.cache) >= maxCacheEntries {
		for k, e := range a.cache {
			if !now.Before(e.expires) {
				delete(a.cache, k)
			}
		}
		if len(a.cache) >= maxCacheEntries {
			a.cache = map[[32]byte]cacheEntry{}
		}
	}
	a.cache[key] = cacheEntry{userID: userID, expires: now.Add(a.ttl)}
	a.mu.Unlock()
	return userID, nil
}

// Server is the HTTP handler. root holds one directory per user.
type Server struct {
	auth     Authenticator
	root     string
	maxBytes int64
	maxFiles int
	logger   *log.Logger
}

func NewServer(auth Authenticator, root string, logger *log.Logger) *Server {
	return &Server{auth: auth, root: root, maxBytes: maxPhotoBytes, maxFiles: maxPhotosPerUser, logger: logger}
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h := w.Header()
	h.Set("Cache-Control", "no-store")
	h.Set("X-Content-Type-Options", "nosniff")

	token, ok := bearerToken(r)
	if !ok {
		h.Set("WWW-Authenticate", "Bearer")
		writeStatus(w, http.StatusUnauthorized)
		return
	}
	userID, err := s.auth.UserID(r.Context(), token)
	switch {
	case err == nil:
	case errors.Is(err, errUnauthorized):
		h.Set("WWW-Authenticate", `Bearer error="invalid_token"`)
		writeStatus(w, http.StatusUnauthorized)
		return
	case errors.Is(err, errNotConfigured):
		writeStatus(w, http.StatusServiceUnavailable)
		return
	default:
		s.logger.Printf("auth check failed: %v", err)
		writeStatus(w, http.StatusBadGateway)
		return
	}
	// Defence in depth: the Authenticator already guarantees this.
	if !userIDPattern.MatchString(userID) {
		writeStatus(w, http.StatusUnauthorized)
		return
	}

	rest, ok := strings.CutPrefix(r.URL.Path, apiPrefix)
	if !ok {
		writeStatus(w, http.StatusNotFound)
		return
	}
	dir := filepath.Join(s.root, userID)
	if rest == "" {
		if r.Method != http.MethodGet {
			h.Set("Allow", "GET")
			writeStatus(w, http.StatusMethodNotAllowed)
			return
		}
		s.list(w, dir)
		return
	}
	if !photoIDPattern.MatchString(rest) {
		writeStatus(w, http.StatusBadRequest)
		return
	}
	path := filepath.Join(dir, rest)
	switch r.Method {
	case http.MethodPut:
		s.put(w, r, dir, path)
	case http.MethodGet, http.MethodHead:
		s.get(w, r, path)
	case http.MethodDelete:
		s.delete(w, path)
	default:
		h.Set("Allow", "GET, HEAD, PUT, DELETE")
		writeStatus(w, http.StatusMethodNotAllowed)
	}
}

func (s *Server) list(w http.ResponseWriter, dir string) {
	photos := map[string]string{}
	entries, err := os.ReadDir(dir)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		s.logger.Printf("list: %v", err)
		writeStatus(w, http.StatusInternalServerError)
		return
	}
	for _, e := range entries {
		if !e.Type().IsRegular() || !photoIDPattern.MatchString(e.Name()) {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		photos[e.Name()] = etagOf(info)
	}
	writeJSON(w, http.StatusOK, map[string]any{"photos": photos})
}

func (s *Server) put(w http.ResponseWriter, r *http.Request, dir, path string) {
	if r.ContentLength > s.maxBytes {
		writeStatus(w, http.StatusRequestEntityTooLarge)
		return
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		s.logger.Printf("put: %v", err)
		writeStatus(w, http.StatusInternalServerError)
		return
	}
	if _, err := os.Lstat(path); errors.Is(err, os.ErrNotExist) && s.countPhotos(dir) >= s.maxFiles {
		writeStatus(w, http.StatusInsufficientStorage)
		return
	}
	tmp, err := os.CreateTemp(dir, tempPrefix+"*")
	if err != nil {
		s.logger.Printf("put: %v", err)
		writeStatus(w, http.StatusInternalServerError)
		return
	}
	tmpName := tmp.Name()
	committed := false
	defer func() {
		if !committed {
			tmp.Close()
			os.Remove(tmpName)
		}
	}()
	n, err := io.Copy(tmp, http.MaxBytesReader(w, r.Body, s.maxBytes))
	if err != nil {
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			writeStatus(w, http.StatusRequestEntityTooLarge)
		} else {
			writeStatus(w, http.StatusBadRequest)
		}
		return
	}
	if n == 0 {
		writeStatus(w, http.StatusBadRequest)
		return
	}
	if err := tmp.Sync(); err != nil {
		s.logger.Printf("put: %v", err)
		writeStatus(w, http.StatusInternalServerError)
		return
	}
	if err := tmp.Close(); err != nil {
		s.logger.Printf("put: %v", err)
		writeStatus(w, http.StatusInternalServerError)
		return
	}
	if err := os.Rename(tmpName, path); err != nil {
		s.logger.Printf("put: %v", err)
		writeStatus(w, http.StatusInternalServerError)
		return
	}
	committed = true
	syncDir(dir)
	info, err := os.Stat(path)
	if err != nil {
		s.logger.Printf("put: %v", err)
		writeStatus(w, http.StatusInternalServerError)
		return
	}
	etag := etagOf(info)
	w.Header().Set("ETag", `"`+etag+`"`)
	writeJSON(w, http.StatusOK, map[string]string{"etag": etag})
}

func (s *Server) get(w http.ResponseWriter, r *http.Request, path string) {
	f, err := os.Open(path)
	if errors.Is(err, os.ErrNotExist) {
		writeStatus(w, http.StatusNotFound)
		return
	}
	if err != nil {
		s.logger.Printf("get: %v", err)
		writeStatus(w, http.StatusInternalServerError)
		return
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil || !info.Mode().IsRegular() {
		writeStatus(w, http.StatusNotFound)
		return
	}
	h := w.Header()
	h.Set("Content-Type", "application/octet-stream")
	h.Set("Content-Length", fmt.Sprint(info.Size()))
	h.Set("ETag", `"`+etagOf(info)+`"`)
	w.WriteHeader(http.StatusOK)
	if r.Method == http.MethodHead {
		return
	}
	io.Copy(w, f)
}

func (s *Server) delete(w http.ResponseWriter, path string) {
	if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
		s.logger.Printf("delete: %v", err)
		writeStatus(w, http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) countPhotos(dir string) int {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0
	}
	n := 0
	for _, e := range entries {
		if photoIDPattern.MatchString(e.Name()) {
			n++
		}
	}
	return n
}

// bearerToken returns the token of an `Authorization: Bearer <token>`
// header. Tokens with whitespace, control characters or absurd lengths are
// refused before anything else looks at them.
func bearerToken(r *http.Request) (string, bool) {
	header := r.Header.Get("Authorization")
	scheme, token, ok := strings.Cut(header, " ")
	if !ok || !strings.EqualFold(scheme, "Bearer") {
		return "", false
	}
	if token == "" || len(token) > maxTokenLength {
		return "", false
	}
	for i := 0; i < len(token); i++ {
		if c := token[i]; c <= ' ' || c >= 0x7f {
			return "", false
		}
	}
	return token, true
}

// etagOf changes whenever a photo is replaced: every PUT renames a new file
// into place, which gets a new modification time.
func etagOf(info os.FileInfo) string {
	return fmt.Sprintf("%x-%x", info.Size(), info.ModTime().UnixNano())
}

func syncDir(dir string) {
	if d, err := os.Open(dir); err == nil {
		d.Sync()
		d.Close()
	}
}

func writeStatus(w http.ResponseWriter, code int) {
	writeJSON(w, code, map[string]string{"error": http.StatusText(code)})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

// removeStaleTemps deletes upload temp files left by a crash mid-PUT.
func removeStaleTemps(root string) {
	users, err := os.ReadDir(root)
	if err != nil {
		return
	}
	for _, u := range users {
		if !u.IsDir() || !userIDPattern.MatchString(u.Name()) {
			continue
		}
		dir := filepath.Join(root, u.Name())
		files, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, f := range files {
			if strings.HasPrefix(f.Name(), tempPrefix) {
				os.Remove(filepath.Join(dir, f.Name()))
			}
		}
	}
}

func envOr(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}

func main() {
	logger := log.New(os.Stderr, "ont-photos: ", log.LstdFlags)
	addr := envOr("PHOTOS_LISTEN", "127.0.0.1:8081")
	root := envOr("PHOTOS_DIR", "/data/photos")
	baseURL := strings.TrimSpace(os.Getenv("SUPABASE_URL"))
	anonKey := strings.TrimSpace(os.Getenv("SUPABASE_ANON_KEY"))

	if baseURL != "" {
		u, err := url.Parse(baseURL)
		if err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" {
			logger.Printf("SUPABASE_URL is not a valid http(s) URL; every request will be refused")
			baseURL = ""
		}
	}
	if baseURL == "" || anonKey == "" {
		logger.Printf("SUPABASE_URL or SUPABASE_ANON_KEY is not set; every request will be refused")
	}
	if err := os.MkdirAll(root, 0o700); err != nil {
		logger.Fatalf("cannot create %s: %v", root, err)
	}
	probe, err := os.CreateTemp(root, tempPrefix+"probe-*")
	if err != nil {
		logger.Fatalf("%s is not writable: %v", root, err)
	}
	probe.Close()
	os.Remove(probe.Name())
	removeStaleTemps(root)

	srv := &http.Server{
		Addr:              addr,
		Handler:           NewServer(NewSupabaseAuth(baseURL, anonKey, nil), root, logger),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       2 * time.Minute,
		WriteTimeout:      2 * time.Minute,
		IdleTimeout:       2 * time.Minute,
		MaxHeaderBytes:    32 << 10,
	}
	logger.Printf("listening on %s, storing in %s", addr, root)
	logger.Fatal(srv.ListenAndServe())
}
