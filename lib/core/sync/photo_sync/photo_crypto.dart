import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// A photo blob that is not a version this app wrote, is cut short, was
/// encrypted with another key or for another photo id, or was altered.
class PhotoCryptoException implements Exception {
  final String message;

  const PhotoCryptoException(this.message);

  @override
  String toString() => 'PhotoCryptoException: $message';
}

/// End-to-end encryption of account photos (photos-service/).
///
/// Two keys are derived from the account data key with HKDF-SHA256 (no
/// salt), each with its own info string so neither can stand in for the
/// data key or for the other:
/// - `ont-photo-v1`: AES-256-GCM key for the photo bytes.
/// - `ont-photo-id-v1`: HMAC-SHA256 key that turns a local slug
///   (`meal_images/<code>.webp`) into the photo id the server sees, 64 hex
///   characters. The server never learns slugs, meal codes or recipe ids.
///
/// Blob format: `0x01 ‖ nonce (12) ‖ ciphertext ‖ tag (16)`. The version
/// byte and the photo id are the GCM associated data, so the server cannot
/// swap one photo's blob for another's: it fails to decrypt.
class PhotoCrypto {
  static const int version = 1;
  static const int _nonceLength = 12;
  static const int _tagLength = 16;
  static const String _encInfo = 'ont-photo-v1';
  static const String _idInfo = 'ont-photo-id-v1';

  static final AesGcm _aes = AesGcm.with256bits();
  static final Hmac _hmac = Hmac.sha256();

  final SecretKey _encKey;
  final SecretKey _idKey;

  PhotoCrypto._(this._encKey, this._idKey);

  /// The photo keys of the account data key [dataKey] (32 bytes).
  static Future<PhotoCrypto> derive(Uint8List dataKey) async {
    if (dataKey.length != 32) {
      throw ArgumentError.value(dataKey.length, 'dataKey', 'must be 32 bytes');
    }
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final secret = SecretKey(dataKey);
    final enc = await hkdf.deriveKey(secretKey: secret, info: utf8.encode(_encInfo));
    final id = await hkdf.deriveKey(secretKey: secret, info: utf8.encode(_idInfo));
    return PhotoCrypto._(
      SecretKey(Uint8List.fromList(await enc.extractBytes())),
      SecretKey(Uint8List.fromList(await id.extractBytes())),
    );
  }

  /// The server-side name of the photo at [slug]: lowercase hex HMAC.
  Future<String> photoId(String slug) async {
    final mac = await _hmac.calculateMac(utf8.encode(slug), secretKey: _idKey);
    return _hex(mac.bytes);
  }

  Future<Uint8List> encrypt(Uint8List plain, String photoId) async {
    final nonce = _randomBytes(_nonceLength);
    final box = await _aes.encrypt(plain, secretKey: _encKey, nonce: nonce, aad: _aad(photoId));
    final out = BytesBuilder(copy: false)
      ..addByte(version)
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  /// Throws [PhotoCryptoException] unless [blob] was written by [encrypt]
  /// with these keys for this [photoId] and is intact.
  Future<Uint8List> decrypt(Uint8List blob, String photoId) async {
    if (blob.length < 1 + _nonceLength + _tagLength) throw const PhotoCryptoException('blob too short');
    if (blob[0] != version) throw PhotoCryptoException('unknown version ${blob[0]}');
    final nonce = Uint8List.sublistView(blob, 1, 1 + _nonceLength);
    final cipherText = Uint8List.sublistView(blob, 1 + _nonceLength, blob.length - _tagLength);
    final tag = Uint8List.sublistView(blob, blob.length - _tagLength);
    try {
      final plain = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: _encKey,
        aad: _aad(photoId),
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const PhotoCryptoException('authentication failed');
    }
  }

  static List<int> _aad(String photoId) => [version, ...utf8.encode(photoId)];

  static String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
  }
}
