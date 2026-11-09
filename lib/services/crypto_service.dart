import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:bc_ur_dart/bc_ur_dart.dart';

class DecryptionResult {
  final bool success;
  final dynamic data;
  final String? jsonString;
  final String? error;
  final Uint8List? iv;
  final Uint8List? rawCiphertext;

  DecryptionResult({
    required this.success,
    this.data,
    this.jsonString,
    this.error,
    this.iv,
    this.rawCiphertext,
  });
}

class CryptoService {
  /// Default secret key provided in specification
  static const String defaultSecretKeyHex =
      "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

  /// Decrypt an encrypted payload (12-byte IV + AES-GCM ciphertext + 16-byte tag)
  static Future<DecryptionResult> decryptPayload({
    required Uint8List encryptedPayload,
    String secretKeyHex = defaultSecretKeyHex,
  }) async {
    try {
      if (encryptedPayload.length < 28) {
        // 12 bytes IV + at least 16 bytes MAC = 28 bytes minimum
        return DecryptionResult(
          success: false,
          error: "Invalid encrypted payload length: ${encryptedPayload.length} bytes. Minimum 28 bytes required.",
        );
      }

      // 1. Separate the 12-byte IV from the rest of the encrypted ciphertext
      final iv = encryptedPayload.sublist(0, 12);
      final ciphertextWithMac = encryptedPayload.sublist(12);

      // In AES-GCM (Web Crypto API Subtle.encrypt/decrypt standard),
      // the authentication tag (MAC) is the final 16 bytes of the ciphertext.
      final cipherText = ciphertextWithMac.sublist(0, ciphertextWithMac.length - 16);
      final mac = ciphertextWithMac.sublist(ciphertextWithMac.length - 16);

      // 2. Initialize the local decryption key
      final rawKey = hexToBytes(secretKeyHex);
      final algorithm = AesGcm.with256bits();
      final secretKey = await algorithm.newSecretKeyFromBytes(rawKey);

      // 3. Decrypt completely offline
      final secretBox = SecretBox(
        cipherText,
        nonce: iv,
        mac: Mac(mac),
      );

      final decryptedBytes = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      final jsonString = utf8.decode(decryptedBytes);
      dynamic parsed;
      try {
        parsed = jsonDecode(jsonString);
      } catch (_) {
        parsed = jsonString;
      }

      return DecryptionResult(
        success: true,
        data: parsed,
        jsonString: jsonString,
        iv: iv,
        rawCiphertext: ciphertextWithMac,
      );
    } catch (authError) {
      return DecryptionResult(
        success: false,
        error: "Decryption failed! The key may be mismatched or data was tampered with. ($authError)",
      );
    }
  }

  /// Encrypt arbitrary data to produce a valid UR string: ur:bytes/...
  /// Useful for testing, generating sample QR codes, or communicating with partner services.
  static Future<String> createEncryptedUr({
    required String jsonOrText,
    String secretKeyHex = defaultSecretKeyHex,
  }) async {
    final rawKey = hexToBytes(secretKeyHex);
    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKeyFromBytes(rawKey);

    // 12-byte IV (nonce)
    final nonce = algorithm.newNonce();

    // Encrypt
    final secretBox = await algorithm.encrypt(
      utf8.encode(jsonOrText),
      secretKey: secretKey,
      nonce: nonce,
    );

    // Concatenate IV (12 bytes) + Ciphertext + Tag (16 bytes)
    final builder = BytesBuilder(copy: false);
    builder.add(secretBox.nonce);
    builder.add(secretBox.cipherText);
    builder.add(secretBox.mac.bytes);
    final encryptedPayload = builder.takeBytes();

    // CBOR encode the byte string (Major type 2)
    final cborEncoded = cbor.encode(CborBytes(encryptedPayload));

    // Wrap in UR
    final ur = UR(type: 'bytes', payload: Uint8List.fromList(cborEncoded));
    return ur.encode();
  }

  /// Converts hex string to byte array
  static Uint8List hexToBytes(String hex) {
    final cleanHex = hex.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final result = Uint8List(cleanHex.length ~/ 2);
    for (int i = 0; i < cleanHex.length; i += 2) {
      result[i ~/ 2] = int.parse(cleanHex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Converts byte array to hex string
  static String bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Search recursively or with regex for a URL in parsed data or string
  static String? extractUrl(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      final urlRegExp = RegExp(
        r'(https?:\/\/[^\s<>"{}|\\^`\[\]]+)',
        caseSensitive: false,
      );
      final match = urlRegExp.firstMatch(trimmed);
      if (match != null) {
        return match.group(0);
      }
      return null;
    }

    if (data is Map) {
      // Check common URL key names first
      const priorityKeys = [
        'url',
        'link',
        'web_url',
        'webUrl',
        'chrome_url',
        'chromeUrl',
        'redirect_url',
        'checkout_url',
        'order_url',
        'uri',
        'website',
      ];

      for (final key in priorityKeys) {
        if (data.containsKey(key) && data[key] is String) {
          final val = (data[key] as String).trim();
          if (val.isNotEmpty) {
            return val.startsWith('http') ? val : 'https://$val';
          }
        }
      }

      // Check all values
      for (final value in data.values) {
        final extracted = extractUrl(value);
        if (extracted != null) return extracted;
      }
    }

    if (data is List) {
      for (final item in data) {
        final extracted = extractUrl(item);
        if (extracted != null) return extracted;
      }
    }

    return null;
  }
}
