# QR Secure Scanner (Flutter)

A modern, high-performance Flutter application designed to scan QR codes with camera, assemble single-part and multi-part **BC-UR (Blockchain Commons Uniform Resources)** payloads, decrypt offline **AES-256-GCM** encrypted orders/data using `@ngraveio/bc-ur` compatible algorithms, display formatted data, and open target links directly in **Google Chrome / default browser**.

---

## 🚀 Key Features

1. **Modern Camera QR Scanning:**
   - Powered by the latest `mobile_scanner` (v7.5+).
   - High frame-rate detection with autofocus, flashlight (torch) toggle, and front/rear camera flip.
   - Sleek cyber-viewfinder with animated laser scanning line.

2. **Blockchain Commons UR Decoder (`@ngraveio/bc-ur` compatible):**
   - Built with `bc_ur_dart` to decode `ur:bytes/...` payloads.
   - Handles both **single-part** and **multi-part fountain-code animated QR codes**.
   - Live progress indicator showing collected parts count (`X / Y parts`) and percentage.

3. **Offline AES-256-GCM Decryption:**
   - Implements the exact cryptographic workflow from Web Crypto API / Node.js SubtleCrypto:
     - 12-byte Initialization Vector (IV/nonce) separation
     - AES-256-GCM key import from 64-character hex (`SECRET_KEY_HEX`)
     - 16-byte authentication tag (MAC) verification
     - Fully offline decryption into JSON/text.

4. **One-Tap "Open in Chrome" / External Browser:**
   - Deep integration with `url_launcher`.
   - Automatically detects and extracts web URLs from decrypted JSON payloads (e.g. `url`, `link`, `checkout_url`, `order_url`, etc.) or direct URL QR codes.
   - Prominent **"Open in Chrome"** button launches external browser directly.
   - Fallback web search button if an order ID or search text is scanned without an explicit URL.

5. **Built-in Test QR Generator & Scanner Simulator:**
   - Allows generating encrypted `ur:bytes/...` QR codes directly on-device with custom or preset JSON data.
   - **"Simulate Scan in App Now"** feature enables testing the decryption and Chrome opening instantly without needing a second physical device!

6. **Scan History & Manual Input:**
   - Keeps track of previous scans with quick launch buttons.
   - Manual paste option to test raw UR or text strings directly.
   - Secret key manager allowing custom 256-bit keys while defaulting to:
     ```
     0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
     ```

---

## 🛠️ Flutter Packages Used

| Package | Version | Purpose |
|---|---|---|
| `mobile_scanner` | `^7.5.0` | Real-time camera QR scanning with camera controls |
| `bc_ur_dart` | `^0.1.30` | Pure Dart BC-UR encoder/decoder & CBOR handling |
| `cryptography` | `^2.9.0` | Hardware-accelerated AES-256-GCM encryption & decryption |
| `url_launcher` | `^6.3.3` | Launch URLs in Google Chrome / external applications |
| `qr_flutter` | `^4.1.0` | Built-in test QR code rendering on device |

---

## 📂 Project Structure

```
lib/
├── main.dart                      # App entry point, system themes (Dark/Light Material 3)
├── models/
│   └── scan_item.dart             # Data model for scans (data type, decrypted JSON, URL, error)
├── screens/
│   ├── scanner_screen.dart        # Camera view, viewfinder, flash/switch controls, UR progress
│   ├── result_screen.dart         # Decrypted data presentation, "Open in Chrome" button, JSON tree
│   ├── generator_screen.dart      # Test encrypted QR generator & in-app scan simulator
│   └── history_screen.dart        # Past scan logs and quick action links
├── services/
│   ├── browser_service.dart       # Chrome / external browser launcher & search handler
│   ├── crypto_service.dart        # AES-GCM 256-bit offline decryption & encryption
│   └── ur_decoder.dart            # URDecoder implementation matching @ngraveio/bc-ur
└── widgets/
    └── scanner_overlay.dart       # Custom animated viewfinder overlay with laser animation
```

---

## 🔒 Specification Implementation Comparison

### JavaScript Reference:
```javascript
import { URDecoder } from '@ngraveio/bc-ur';

const decoder = new URDecoder();
const SECRET_KEY_HEX = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

async function onQRCodeScanned(scannedText) {
    decoder.receivePart(scannedText);

    if (decoder.isComplete()) {
        const resultUR = decoder.resultUR();
        const encryptedPayload = resultUR.decodeCBOR(); // Raw binary bytes

        // 1. Separate the 12-byte IV from the rest of the encrypted ciphertext
        const iv = encryptedPayload.slice(0, 12);
        const ciphertext = encryptedPayload.slice(12);

        // 2. Initialize the local decryption key
        const rawKey = new Uint8Array(SECRET_KEY_HEX.match(/.{1,2}/g).map(byte => parseInt(byte, 16)));
        const cryptoKey = await crypto.subtle.importKey(
            "raw", rawKey, { name: "AES-GCM" }, false, ["decrypt"]
        );

        try {
            // 3. Decrypt completely offline
            const decryptedBuffer = await crypto.subtle.decrypt(
                { name: "AES-GCM", iv: iv }, cryptoKey, ciphertext
            );

            const jsonString = new TextDecoder().decode(decryptedBuffer);
            const originalOrder = JSON.parse(jsonString);

            console.log("Secure Order Safely Received!", originalOrder);
            // Process order...
        } catch (authError) {
            console.error("Decryption failed! The key may be mismatched or data was tampered with.", authError);
        }
    }
}
```

### Flutter / Dart Implementation (`lib/services/ur_decoder.dart` & `lib/services/crypto_service.dart`):
```dart
// 1. Feed QR part to URDecoder
_urDecoder.receivePart(scannedText);

if (_urDecoder.isComplete()) {
  final resultUR = _urDecoder.resultUR();
  final encryptedPayload = URDecoder.extractCBORBytes(resultUR);

  // 2. Decrypt with AES-GCM
  final decResult = await CryptoService.decryptPayload(
    encryptedPayload: encryptedPayload,
    secretKeyHex: SECRET_KEY_HEX,
  );

  if (decResult.success) {
    print("Secure Order Safely Received! ${decResult.data}");
    // 3. Open in Chrome
    final url = CryptoService.extractUrl(decResult.data);
    if (url != null) {
      await BrowserService.openInBrowser(url);
    }
  }
}
```

---

## 📱 How to Run

### Run on Connected Device / Emulator:
```bash
flutter run
```

### Build Android APK:
```bash
flutter build apk --release
# APK is generated at: build/app/outputs/flutter-apk/app-release.apk
```

### Run Automated Tests:
```bash
flutter test
```
