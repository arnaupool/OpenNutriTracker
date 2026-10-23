import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// End-to-end encryption for sync payloads (FAS-01).
///
/// AES-256-GCM with a random 96-bit nonce per record. The key never leaves
/// the devices: it travels only inside the pairing code, so the server
/// stores ciphertext it cannot read, and GCM's tag makes any tampering fail
/// decryption instead of producing garbage records.
///
/// Wire format: base64(nonce ‖ ciphertext ‖ tag).
class SyncCrypto {
  static const int keyLength = 32;
  static const int _nonceLength = 12;
  static const int _tagBits = 128;

  final Uint8List _key;

  SyncCrypto(Uint8List key) : _key = key {
    if (key.length != keyLength) {
      throw ArgumentError.value(key.length, 'key', 'must be $keyLength bytes');
    }
  }

  static Uint8List generateKey() => _randomBytes(keyLength);

  String encrypt(String plaintext) {
    final nonce = _randomBytes(_nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(_key), _tagBits, nonce, Uint8List(0)));
    final sealed = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    final out = Uint8List(nonce.length + sealed.length)
      ..setAll(0, nonce)
      ..setAll(nonce.length, sealed);
    return base64Encode(out);
  }

  /// Throws [InvalidCipherTextException] when the payload was encrypted
  /// with another key or altered.
  String decrypt(String payload) {
    final bytes = base64Decode(payload);
    if (bytes.length < _nonceLength + _tagBits ~/ 8) {
      throw InvalidCipherTextException('payload too short');
    }
    final nonce = Uint8List.sublistView(bytes, 0, _nonceLength);
    final sealed = Uint8List.sublistView(bytes, _nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(_key), _tagBits, nonce, Uint8List(0)));
    return utf8.decode(cipher.process(sealed));
  }

  /// Keyed, one-way name for a box or record id, so the server can tell rows
  /// apart without learning what they are (a weigh-in id is its date).
  String opaqueId(String text) {
    final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(_key));
    final digest = mac.process(Uint8List.fromList(utf8.encode(text)));
    return base64Url.encode(digest.sublist(0, 18));
  }

  /// Short stable fingerprint of a record's JSON, used to notice local
  /// changes between syncs without keeping a copy of every record.
  static String fingerprint(String json) {
    final digest = SHA256Digest().process(Uint8List.fromList(utf8.encode(json)));
    return base64Encode(digest.sublist(0, 16));
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
  }
}
