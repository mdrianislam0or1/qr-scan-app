import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/scan_item.dart';
import '../services/crypto_service.dart';
import '../services/ur_decoder.dart';
import '../widgets/scanner_overlay.dart';
import 'generator_screen.dart';
import 'history_screen.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  final URDecoder _urDecoder = URDecoder();

  String _secretKeyHex = CryptoService.defaultSecretKeyHex;
  final List<ScanItem> _scanHistory = [];

  bool _isProcessing = false;
  bool _isMultiPartScanning = false;
  double _multiPartProgress = 0.0;
  int _receivedParts = 0;
  int _expectedParts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
      autoStart: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      _controller.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  /// Processes scanned QR text using BC-UR Decoder and AES-GCM decryption
  Future<void> onQRCodeScanned(String scannedText) async {
    if (_isProcessing) return;

    final trimmed = scannedText.trim();
    if (trimmed.isEmpty) return;

    // Check if this is a BC-UR (starts with ur:)
    if (trimmed.toLowerCase().startsWith('ur:')) {
      final accepted = _urDecoder.receivePart(trimmed);

      if (!accepted && !_urDecoder.isComplete()) {
        // If not accepted, might be an invalid UR format
        return;
      }

      if (!_urDecoder.isComplete()) {
        // Multipart fragmented UR: update progress indicator
        setState(() {
          _isMultiPartScanning = true;
          _multiPartProgress = _urDecoder.getProgress();
          _receivedParts = _urDecoder.receivedPartsCount;
          _expectedParts = _urDecoder.expectedPartsCount;
        });
        return;
      }

      // Decoder is complete!
      _isProcessing = true;
      HapticFeedback.heavyImpact();

      final resultUR = _urDecoder.resultUR();
      final encryptedPayload = URDecoder.extractCBORBytes(resultUR);

      // Decrypt using AES-GCM with SECRET_KEY_HEX
      final decResult = await CryptoService.decryptPayload(
        encryptedPayload: encryptedPayload,
        secretKeyHex: _secretKeyHex,
      );

      final String? extractedUrl = CryptoService.extractUrl(decResult.data);

      final scanItem = ScanItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rawScanned: trimmed,
        dataType: ScanDataType.encryptedUr,
        isDecrypted: decResult.success,
        urType: resultUR.type,
        parsedData: decResult.data,
        rawJsonString: decResult.jsonString,
        extractedUrl: extractedUrl,
        error: decResult.error,
        partsCount: _receivedParts > 0 ? _receivedParts : 1,
      );

      _finishScan(scanItem);
    } else {
      // Standard QR code (Direct URL or plain text/JSON)
      _isProcessing = true;
      HapticFeedback.mediumImpact();

      final String? extractedUrl = CryptoService.extractUrl(trimmed);
      dynamic parsedJson;
      try {
        parsedJson = jsonDecode(trimmed);
      } catch (_) {
        parsedJson = null;
      }

      final scanItem = ScanItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rawScanned: trimmed,
        dataType: extractedUrl != null && trimmed.startsWith('http')
            ? ScanDataType.directUrl
            : (parsedJson != null ? ScanDataType.plainJson : ScanDataType.plainText),
        isDecrypted: false,
        parsedData: parsedJson ?? trimmed,
        rawJsonString: parsedJson != null ? trimmed : null,
        extractedUrl: extractedUrl,
      );

      _finishScan(scanItem);
    }
  }

  void _finishScan(ScanItem item) {
    setState(() {
      _scanHistory.insert(0, item);
      _isMultiPartScanning = false;
      _multiPartProgress = 0.0;
      _receivedParts = 0;
      _expectedParts = 0;
    });

    _urDecoder.reset();

    // Navigate to Result Screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(item: item)),
    ).then((_) {
      // Resume scanning after user returns
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  void _showManualInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual QR / UR Input'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a UR string (ur:bytes/...) or URL to simulate scan:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'ur:bytes/... or https://...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                onQRCodeScanned(text);
              }
            },
            child: const Text('Process'),
          ),
        ],
      ),
    );
  }

  void _showKeySettingsDialog() {
    final keyController = TextEditingController(text: _secretKeyHex);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Secret Key Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AES-256-GCM 32-byte hex key:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: keyController,
              maxLines: 2,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: '64 hex characters',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                keyController.text = CryptoService.defaultSecretKeyHex;
              },
              child: const Text('Reset to Default Key'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newKey = keyController.text.trim();
              if (newKey.length == 64) {
                setState(() {
                  _secretKeyHex = newKey;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Secret key updated successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Key must be exactly 64 hex characters (32 bytes).')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;

    // Viewfinder cutout rectangle
    final scanSize = size.width * 0.72;
    final scanWindow = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 40),
      width: scanSize,
      height: scanSize,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: (BarcodeCapture capture) {
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  onQRCodeScanned(barcode.rawValue!);
                  break;
                }
              }
            },
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Camera Error: ${error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please verify camera permissions in device settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _controller.start(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry Camera'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Custom Scanner Overlay with Viewfinder & Animated Laser
          ScannerOverlay(scanWindow: scanWindow),

          // Top Action Bar
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // App Logo / Title Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF00E676), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'QR Secure Scanner',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Key Settings
                    _buildTopIconBtn(
                      icon: Icons.key_rounded,
                      tooltip: 'Key Settings',
                      onTap: _showKeySettingsDialog,
                    ),
                    const SizedBox(width: 8),

                    // Test Generator
                    _buildTopIconBtn(
                      icon: Icons.auto_awesome_rounded,
                      tooltip: 'Test Generator',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GeneratorScreen(
                              onSimulateScan: (scanned) {
                                onQRCodeScanned(scanned);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),

                    // History
                    _buildTopIconBtn(
                      icon: Icons.history_rounded,
                      tooltip: 'History',
                      badgeCount: _scanHistory.length,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistoryScreen(
                              history: _scanHistory,
                              onClear: () {
                                setState(() {
                                  _scanHistory.clear();
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Multi-part Fragment Progress Indicator (Animated UR)
          if (_isMultiPartScanning)
            Align(
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.only(top: 260),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Assembling Animated QR: $_receivedParts / $_expectedParts parts',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        value: _multiPartProgress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Controls (Torch, Camera Switch, Manual Input)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flashlight / Torch
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _controller,
                      builder: (context, state, child) {
                        final isTorchOn = state.torchState == TorchState.on;
                        return IconButton(
                          icon: Icon(
                            isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: isTorchOn ? const Color(0xFFFFD600) : Colors.white,
                            size: 26,
                          ),
                          tooltip: 'Flashlight',
                          onPressed: () => _controller.toggleTorch(),
                        );
                      },
                    ),
                    const SizedBox(width: 16),

                    // Manual Paste / Text Input
                    IconButton(
                      icon: const Icon(Icons.paste_rounded, color: Colors.white, size: 26),
                      tooltip: 'Paste / Manual Input',
                      onPressed: _showManualInputDialog,
                    ),
                    const SizedBox(width: 16),

                    // Switch Camera (Front / Back)
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 26),
                      tooltip: 'Switch Camera',
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 20),
            tooltip: tooltip,
            onPressed: onTap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (badgeCount != null && badgeCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
