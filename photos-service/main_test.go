package main

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

const (
	userA  = "11111111-1111-1111-1111-111111111111"
	userB  = "22222222-2222-2222-2222-222222222222"
	tokenA = "token-a"
	tokenB = "token-b"
	anon   = "anon-key"
)

var photoID = strings.Repeat("ab", 32)

// fakeSupabase answers /auth/v1/user like Supabase Auth: the user of a known
// token, 401 for anything else. It counts the calls.
type fakeSupabase struct {
	server *httptest.Server
	calls  atomic.Int64
	status atomic.Int64 // when non-zero, every call answers this status
}

func newFakeSupabase(t *testing.T) *fakeSupabase {
	f := &fakeSupabase{}
	users := map[string]string{tokenA: userA, tokenB: userB}
	f.server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.calls.Add(1)
		if r.URL.Path != "/auth/v1/user" || r.Header.Get("apikey") != anon {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		if s := f.status.Load(); s != 0 {
			w.WriteHeader(int(s))
			return
		}
		id, ok := users[strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")]
		if !ok {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"id": id})
	}))
	t.Cleanup(f.server.Close)
	return f
}

type harness struct {
	root     string
	supabase *fakeSupabase
	auth     *SupabaseAuth
	handler  *Server
}

func newHarness(t *testing.T) *harness {
	root := t.TempDir()
	sb := newFakeSupabase(t)
	auth := NewSupabaseAuth(sb.server.URL, anon, sb.server.Client())
	return &harness{root: root, supabase: sb, auth: auth, handler: NewServer(auth, root, log.New(io.Discard, "", 0))}
}

func (h *harness) do(method, path, token string, body []byte) *httptest.ResponseRecorder {
	var reader io.Reader
	if body != nil {
		reader = bytes.NewReader(body)
	}
	req := httptest.NewRequest(method, path, reader)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	h.handler.ServeHTTP(rec, req)
	return rec
}

func TestAuthRequired(t *testing.T) {
	h := newHarness(t)
	for _, path := range []string{"/photos-api/", "/photos-api/v1/", "/photos-api/v1/" + photoID} {
		if rec := h.do(http.MethodGet, path, "", nil); rec.Code != http.StatusUnauthorized {
			t.Errorf("GET %s without token: %d, want 401", path, rec.Code)
		}
	}
	if rec := h.do(http.MethodPut, "/photos-api/v1/"+photoID, "", []byte("x")); rec.Code != http.StatusUnauthorized {
		t.Errorf("PUT without token: %d", rec.Code)
	}
	if h.supabase.calls.Load() != 0 {
		t.Errorf("requests without a token reached Supabase")
	}
	// Wrong scheme, and a token Supabase refuses.
	req := httptest.NewRequest(http.MethodGet, "/photos-api/v1/", nil)
	req.Header.Set("Authorization", "Basic "+tokenA)
	rec := httptest.NewRecorder()
	h.handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("Basic auth: %d", rec.Code)
	}
	if rec := h.do(http.MethodGet, "/photos-api/v1/", "forged", nil); rec.Code != http.StatusUnauthorized {
		t.Errorf("refused token: %d", rec.Code)
	}
	if _, err := os.Stat(filepath.Join(h.root, userA)); err == nil {
		t.Errorf("an unauthenticated request created storage")
	}
}

func TestBearerTokenRejectsMalformed(t *testing.T) {
	for _, header := range []string{"", "Bearer", "Bearer ", "Bearer a b", "Bearer a\tb", "Bearer " + strings.Repeat("a", maxTokenLength+1)} {
		req := httptest.NewRequest(http.MethodGet, "/photos-api/v1/", nil)
		req.Header.Set("Authorization", header)
		if _, ok := bearerToken(req); ok {
			t.Errorf("accepted %q", header)
		}
	}
}

func TestPutGetHeadDeleteRoundTrip(t *testing.T) {
	h := newHarness(t)
	path := "/photos-api/v1/" + photoID
	body := []byte("ciphertext")
	rec := h.do(http.MethodPut, path, tokenA, body)
	if rec.Code != http.StatusOK {
		t.Fatalf("PUT: %d %s", rec.Code, rec.Body)
	}
	var put struct{ Etag string }
	json.Unmarshal(rec.Body.Bytes(), &put)
	if put.Etag == "" {
		t.Fatalf("PUT returned no etag")
	}
	stored, err := os.ReadFile(filepath.Join(h.root, userA, photoID))
	if err != nil || !bytes.Equal(stored, body) {
		t.Fatalf("file not stored under the user: %v", err)
	}

	rec = h.do(http.MethodGet, path, tokenA, nil)
	if rec.Code != http.StatusOK || !bytes.Equal(rec.Body.Bytes(), body) {
		t.Fatalf("GET: %d %q", rec.Code, rec.Body)
	}
	if rec.Header().Get("ETag") != `"`+put.Etag+`"` {
		t.Errorf("GET etag %s, PUT etag %s", rec.Header().Get("ETag"), put.Etag)
	}
	rec = h.do(http.MethodHead, path, tokenA, nil)
	if rec.Code != http.StatusOK || rec.Body.Len() != 0 {
		t.Errorf("HEAD: %d, body %d bytes", rec.Code, rec.Body.Len())
	}

	rec = h.do(http.MethodGet, "/photos-api/v1/", tokenA, nil)
	var list struct{ Photos map[string]string }
	json.Unmarshal(rec.Body.Bytes(), &list)
	if rec.Code != http.StatusOK || list.Photos[photoID] != put.Etag || len(list.Photos) != 1 {
		t.Errorf("list: %d %s", rec.Code, rec.Body)
	}

	// A replacement gets a new etag.
	time.Sleep(5 * time.Millisecond)
	rec = h.do(http.MethodPut, path, tokenA, []byte("other ciphertext"))
	var replaced struct{ Etag string }
	json.Unmarshal(rec.Body.Bytes(), &replaced)
	if replaced.Etag == put.Etag {
		t.Errorf("replacement kept the etag")
	}

	if rec := h.do(http.MethodDelete, path, tokenA, nil); rec.Code != http.StatusNoContent {
		t.Errorf("DELETE: %d", rec.Code)
	}
	if rec := h.do(http.MethodGet, path, tokenA, nil); rec.Code != http.StatusNotFound {
		t.Errorf("GET after DELETE: %d", rec.Code)
	}
	if rec := h.do(http.MethodDelete, path, tokenA, nil); rec.Code != http.StatusNoContent {
		t.Errorf("second DELETE: %d", rec.Code)
	}
	leftovers, _ := os.ReadDir(filepath.Join(h.root, userA))
	if len(leftovers) != 0 {
		t.Errorf("files left behind: %v", leftovers)
	}
}

func TestOtherUserCannotReadOrDelete(t *testing.T) {
	h := newHarness(t)
	path := "/photos-api/v1/" + photoID
	if rec := h.do(http.MethodPut, path, tokenA, []byte("a's photo")); rec.Code != http.StatusOK {
		t.Fatalf("PUT: %d", rec.Code)
	}
	if rec := h.do(http.MethodGet, path, tokenB, nil); rec.Code != http.StatusNotFound {
		t.Errorf("B read A's photo: %d %q", rec.Code, rec.Body)
	}
	rec := h.do(http.MethodGet, "/photos-api/v1/", tokenB, nil)
	if strings.Contains(rec.Body.String(), photoID) {
		t.Errorf("B's list shows A's photo: %s", rec.Body)
	}
	h.do(http.MethodDelete, path, tokenB, nil)
	h.do(http.MethodPut, path, tokenB, []byte("b's photo"))
	stored, _ := os.ReadFile(filepath.Join(h.root, userA, photoID))
	if string(stored) != "a's photo" {
		t.Errorf("B changed A's photo: %q", stored)
	}
	rec = h.do(http.MethodGet, path, tokenA, nil)
	if rec.Body.String() != "a's photo" {
		t.Errorf("A reads %q", rec.Body)
	}
}

func TestPathTraversalRejected(t *testing.T) {
	h := newHarness(t)
	secret := filepath.Join(h.root, "secret")
	os.WriteFile(secret, []byte("x"), 0o600)
	paths := []string{
		"/photos-api/v1/..%2F..%2Fsecret",
		"/photos-api/v1/../secret",
		"/photos-api/v1/%2e%2e%2f" + userB + "%2f" + photoID,
		"/photos-api/v1/" + userB + "/" + photoID,
		"/photos-api/v1/" + strings.ToUpper(photoID),
		"/photos-api/v1/" + photoID[:63],
		"/photos-api/v1/" + photoID + "0",
		"/photos-api/v1/" + photoID + "/",
		"/photos-api/v1/.upload-123",
		"/photos-api/v1/" + photoID + "%00",
	}
	for _, p := range paths {
		for _, method := range []string{http.MethodGet, http.MethodPut, http.MethodDelete} {
			rec := h.do(method, p, tokenA, []byte("evil"))
			if rec.Code != http.StatusBadRequest && rec.Code != http.StatusNotFound {
				t.Errorf("%s %s: %d", method, p, rec.Code)
			}
		}
	}
	if b, err := os.ReadFile(secret); err != nil || string(b) != "x" {
		t.Errorf("file outside the user's directory was touched")
	}
	entries, _ := os.ReadDir(filepath.Join(h.root, userA))
	if len(entries) != 0 {
		t.Errorf("rejected paths created files: %v", entries)
	}
	if rec := h.do(http.MethodGet, "/other/"+photoID, tokenA, nil); rec.Code != http.StatusNotFound {
		t.Errorf("path outside the API: %d", rec.Code)
	}
}

func TestSizeLimit(t *testing.T) {
	h := newHarness(t)
	h.handler.maxBytes = 1024
	path := "/photos-api/v1/" + photoID
	if rec := h.do(http.MethodPut, path, tokenA, make([]byte, 1025)); rec.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("over the limit with Content-Length: %d", rec.Code)
	}
	// Without Content-Length (chunked): the reader limit still applies.
	req := httptest.NewRequest(http.MethodPut, path, io.LimitReader(zeroReader{}, 4096))
	req.ContentLength = -1
	req.Header.Set("Authorization", "Bearer "+tokenA)
	rec := httptest.NewRecorder()
	h.handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("over the limit without Content-Length: %d", rec.Code)
	}
	entries, _ := os.ReadDir(filepath.Join(h.root, userA))
	if len(entries) != 0 {
		t.Errorf("oversized uploads left files: %v", entries)
	}
	if rec := h.do(http.MethodPut, path, tokenA, make([]byte, 1024)); rec.Code != http.StatusOK {
		t.Errorf("at the limit: %d", rec.Code)
	}
	if rec := h.do(http.MethodPut, path, tokenA, []byte{}); rec.Code != http.StatusBadRequest {
		t.Errorf("empty body: %d", rec.Code)
	}
}

func TestPhotoCountLimit(t *testing.T) {
	h := newHarness(t)
	h.handler.maxFiles = 1
	if rec := h.do(http.MethodPut, "/photos-api/v1/"+photoID, tokenA, []byte("1")); rec.Code != http.StatusOK {
		t.Fatalf("first: %d", rec.Code)
	}
	other := strings.Repeat("cd", 32)
	if rec := h.do(http.MethodPut, "/photos-api/v1/"+other, tokenA, []byte("2")); rec.Code != http.StatusInsufficientStorage {
		t.Errorf("over the count: %d", rec.Code)
	}
	if rec := h.do(http.MethodPut, "/photos-api/v1/"+photoID, tokenA, []byte("3")); rec.Code != http.StatusOK {
		t.Errorf("replacing at the count: %d", rec.Code)
	}
}

type zeroReader struct{}

func (zeroReader) Read(p []byte) (int, error) {
	for i := range p {
		p[i] = 0
	}
	return len(p), nil
}

func TestTokenCache(t *testing.T) {
	h := newHarness(t)
	now := time.Unix(1_700_000_000, 0)
	h.auth.now = func() time.Time { return now }
	for i := 0; i < 5; i++ {
		if rec := h.do(http.MethodGet, "/photos-api/v1/", tokenA, nil); rec.Code != http.StatusOK {
			t.Fatalf("GET: %d", rec.Code)
		}
	}
	if c := h.supabase.calls.Load(); c != 1 {
		t.Errorf("Supabase called %d times within the TTL, want 1", c)
	}
	h.do(http.MethodGet, "/photos-api/v1/", tokenB, nil)
	if c := h.supabase.calls.Load(); c != 2 {
		t.Errorf("another token must be checked on its own: %d calls", c)
	}
	now = now.Add(tokenCacheTTL + time.Second)
	h.do(http.MethodGet, "/photos-api/v1/", tokenA, nil)
	if c := h.supabase.calls.Load(); c != 3 {
		t.Errorf("expired entry not rechecked: %d calls", c)
	}
	// Refused tokens are not cached.
	h.do(http.MethodGet, "/photos-api/v1/", "forged", nil)
	h.do(http.MethodGet, "/photos-api/v1/", "forged", nil)
	if c := h.supabase.calls.Load(); c != 5 {
		t.Errorf("refused token cached: %d calls", c)
	}
	// The cache never holds the token itself.
	for k := range h.auth.cache {
		if strings.Contains(string(k[:]), tokenA) {
			t.Errorf("token stored in the cache key")
		}
	}
}

func TestUpstreamFailures(t *testing.T) {
	h := newHarness(t)
	h.supabase.status.Store(http.StatusInternalServerError)
	if rec := h.do(http.MethodGet, "/photos-api/v1/", tokenA, nil); rec.Code != http.StatusBadGateway {
		t.Errorf("Supabase 500: %d, want 502", rec.Code)
	}
	h.supabase.status.Store(http.StatusForbidden)
	if rec := h.do(http.MethodGet, "/photos-api/v1/", tokenA, nil); rec.Code != http.StatusUnauthorized {
		t.Errorf("Supabase 403: %d, want 401", rec.Code)
	}

	unconfigured := NewServer(NewSupabaseAuth("", "", nil), t.TempDir(), log.New(io.Discard, "", 0))
	req := httptest.NewRequest(http.MethodGet, "/photos-api/v1/", nil)
	req.Header.Set("Authorization", "Bearer "+tokenA)
	rec := httptest.NewRecorder()
	unconfigured.ServeHTTP(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Errorf("not configured: %d, want 503", rec.Code)
	}
}

func TestNonUUIDUserRefused(t *testing.T) {
	sb := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]string{"id": "../../etc"})
	}))
	defer sb.Close()
	root := t.TempDir()
	s := NewServer(NewSupabaseAuth(sb.URL, anon, sb.Client()), root, log.New(io.Discard, "", 0))
	req := httptest.NewRequest(http.MethodPut, "/photos-api/v1/"+photoID, strings.NewReader("x"))
	req.Header.Set("Authorization", "Bearer "+tokenA)
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	if rec.Code == http.StatusOK {
		t.Fatalf("stored a photo for a malformed user id")
	}
	entries, _ := os.ReadDir(root)
	if len(entries) != 0 {
		t.Errorf("created %v", entries)
	}
}

func TestMethodNotAllowed(t *testing.T) {
	h := newHarness(t)
	if rec := h.do(http.MethodPost, "/photos-api/v1/"+photoID, tokenA, []byte("x")); rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("POST: %d", rec.Code)
	}
	if rec := h.do(http.MethodDelete, "/photos-api/v1/", tokenA, nil); rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("DELETE on the list: %d", rec.Code)
	}
}

func TestRemoveStaleTemps(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, userA)
	os.MkdirAll(dir, 0o700)
	os.WriteFile(filepath.Join(dir, tempPrefix+"1"), []byte("x"), 0o600)
	os.WriteFile(filepath.Join(dir, photoID), []byte("x"), 0o600)
	removeStaleTemps(root)
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 || entries[0].Name() != photoID {
		t.Errorf("left %v", entries)
	}
}
