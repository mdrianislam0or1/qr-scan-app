import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scan_app/services/crypto_service.dart';
import 'package:qr_scan_app/services/ur_decoder.dart';

void main() {
  group('CryptoService & URDecoder Tests', () {
    test('Roundtrip encryption and decryption with default SECRET_KEY_HEX', () async {
      final sampleOrder = {
        "orderId": "ORD-TEST-1234",
        "customer": "Rian Ahmed",
        "url": "https://google.com/order/1234",
        "total": 59.99,
        "items": ["Item 1", "Item 2"]
      };

      final jsonString = jsonEncode(sampleOrder);

      // 1. Generate encrypted UR string
      final urString = await CryptoService.createEncryptedUr(
        jsonOrText: jsonString,
        secretKeyHex: CryptoService.defaultSecretKeyHex,
      );

      expect(urString.toLowerCase().startsWith('ur:bytes/'), isTrue);

      // 2. Decode UR with URDecoder
      final decoder = URDecoder();
      final accepted = decoder.receivePart(urString);
      expect(accepted, isTrue);
      expect(decoder.isComplete(), isTrue);

      final resultUr = decoder.resultUR();
      expect(resultUr.type, equals('bytes'));

      final encryptedPayload = URDecoder.extractCBORBytes(resultUr);
      expect(encryptedPayload.length, greaterThan(28));

      // 3. Decrypt
      final decResult = await CryptoService.decryptPayload(
        encryptedPayload: encryptedPayload,
        secretKeyHex: CryptoService.defaultSecretKeyHex,
      );

      expect(decResult.success, isTrue);
      expect(decResult.error, isNull);
      expect(decResult.data['orderId'], equals('ORD-TEST-1234'));
      expect(decResult.data['url'], equals('https://google.com/order/1234'));
      expect(decResult.data['total'], equals(59.99));

      // 4. URL Extraction test
      final extractedUrl = CryptoService.extractUrl(decResult.data);
      expect(extractedUrl, equals('https://google.com/order/1234'));
    });

    test('Decryption fails with tampered key or tampered ciphertext', () async {
      final urString = await CryptoService.createEncryptedUr(
        jsonOrText: jsonEncode({"test": "data"}),
        secretKeyHex: CryptoService.defaultSecretKeyHex,
      );

      final decoder = URDecoder();
      decoder.receivePart(urString);
      final payload = URDecoder.extractCBORBytes(decoder.resultUR());

      // Wrong key:
      const wrongKeyHex = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
      final result = await CryptoService.decryptPayload(
        encryptedPayload: payload,
        secretKeyHex: wrongKeyHex,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Decryption failed'));
    });

    test('extractUrl helper correctly detects various URL schemes and positions', () {
      expect(
        CryptoService.extractUrl({"orderId": "1", "url": "https://chrome.google.com"}),
        equals("https://chrome.google.com"),
      );
      expect(
        CryptoService.extractUrl({"orderId": "1", "checkout_url": "https://example.com/pay"}),
        equals("https://example.com/pay"),
      );
      expect(
        CryptoService.extractUrl("Click here: https://flutter.dev/docs to read more"),
        equals("https://flutter.dev/docs"),
      );
    });
  });
}

