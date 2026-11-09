import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/crypto_service.dart';

class GeneratorScreen extends StatefulWidget {
  final Function(String urString)? onSimulateScan;

  const GeneratorScreen({super.key, this.onSimulateScan});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final TextEditingController _jsonController = TextEditingController();
  final TextEditingController _keyController = TextEditingController(
    text: CryptoService.defaultSecretKeyHex,
  );

  String _generatedUr = '';
  bool _isLoading = false;
  String? _error;

  final List<Map<String, dynamic>> _samplePresets = [
    {
      "name": "Food Delivery Order (Chrome URL)",
      "data": {
        "orderId": "FD-78901",
        "restaurant": "Burger King",
        "url": "https://www.google.com",
        "items": [
          {"name": "Whopper Meal", "qty": 2, "price": 12.99},
          {"name": "Crispy Chicken", "qty": 1, "price": 8.50}
        ],
        "total": 34.48,
        "status": "READY_FOR_PICKUP"
      }
    },
    {
      "name": "E-Commerce Purchase (Flutter Dev)",
      "data": {
        "orderId": "ECOMM-2026",
        "customer": "Rian Ahmed",
        "url": "https://flutter.dev",
        "totalAmount": 129.99,
        "paymentMethod": "CARD",
        "deliveryDate": "2026-11-12"
      }
    },
    {
      "name": "GitHub Repository URL",
      "data": {
        "project": "Flutter QR Scan App",
        "url": "https://github.com",
        "author": "DG Infotech",
        "security": "AES-256-GCM + BC-UR"
      }
    }
  ];

  @override
  void initState() {
    super.initState();
    _applyPreset(_samplePresets[0]["data"]);
  }

  void _applyPreset(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');
    _jsonController.text = encoder.convert(data);
    _generateUr();
  }

  Future<void> _generateUr() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final input = _jsonController.text.trim();
      final key = _keyController.text.trim();

      // Validate JSON
      jsonDecode(input);

      final urString = await CryptoService.createEncryptedUr(
        jsonOrText: input,
        secretKeyHex: key.isEmpty ? CryptoService.defaultSecretKeyHex : key,
      );

      setState(() {
        _generatedUr = urString;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to encrypt: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test QR Code Generator'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Presets row
            const Text(
              'Select Test Preset:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _samplePresets.map((preset) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      avatar: const Icon(Icons.flash_on_rounded, size: 16),
                      label: Text(preset['name'] as String),
                      onPressed: () => _applyPreset(preset['data']),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // JSON Editor
            const Text(
              'Payload JSON (with URL to open in Chrome):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _jsonController,
              maxLines: 7,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Enter JSON payload...',
              ),
              onChanged: (_) => _generateUr(),
            ),
            const SizedBox(height: 16),

            // Generate Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateUr,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline_rounded),
              label: const Text('Encrypt & Generate UR QR'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            ],

            if (_generatedUr.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Encrypted UR QR Code (AES-GCM)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),

              // QR Display
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _generatedUr,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Direct Test / Simulate Scan Button
              if (widget.onSimulateScan != null) ...[
                FilledButton.icon(
                  onPressed: () {
                    final scanned = _generatedUr;
                    Navigator.pop(context);
                    widget.onSimulateScan!(scanned);
                  },
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: const Text('Simulate Scan in App Now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Copy UR button
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generatedUr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied UR string to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy UR String'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Preview UR string
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  _generatedUr,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

