import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scan_item.dart';
import '../services/browser_service.dart';

class ResultScreen extends StatelessWidget {
  final ScanItem item;

  const ResultScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Scan Result', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy all data',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: item.prettyJson));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied payload to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner Card
            _buildStatusCard(context),
            const SizedBox(height: 20),

            // Main "Open in Chrome / Browser" Button if URL exists
            if (item.hasUrl) ...[
              _buildOpenInChromeButton(context, item.extractedUrl!),
              const SizedBox(height: 20),
            ] else if (item.parsedData is Map || item.parsedData is String) ...[
              // Search or open fallback
              _buildSearchFallbackButton(context),
              const SizedBox(height: 20),
            ],

            // Decrypted Content Card / Structured View
            if (item.parsedData != null) ...[
              _buildDataView(context),
              const SizedBox(height: 20),
            ],

            // Raw JSON / Payload Card (Collapsible)
            _buildRawPayloadSection(context),
            const SizedBox(height: 32),

            // Scan Again Button
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan Another QR Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    Color cardColor;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;

    if (item.hasError) {
      cardColor = Colors.red.withValues(alpha: 0.12);
      iconColor = Colors.redAccent;
      icon = Icons.error_outline_rounded;
      title = 'Decryption Failed';
      subtitle = item.error ?? 'Key mismatched or invalid payload.';
    } else if (item.dataType == ScanDataType.encryptedUr) {
      cardColor = const Color(0xFF00C853).withValues(alpha: 0.12);
      iconColor = const Color(0xFF00C853);
      icon = Icons.verified_user_rounded;
      title = 'Secure Order Safely Received!';
      subtitle = 'Decrypted completely offline using AES-256-GCM.';
    } else if (item.dataType == ScanDataType.directUrl) {
      cardColor = Colors.blue.withValues(alpha: 0.12);
      iconColor = Colors.blueAccent;
      icon = Icons.link_rounded;
      title = 'Direct Web Link';
      subtitle = 'Scanned URL ready to open in browser.';
    } else {
      cardColor = Colors.purple.withValues(alpha: 0.12);
      iconColor = Colors.purpleAccent;
      icon = Icons.qr_code_2_rounded;
      title = 'Scanned QR Data';
      subtitle = 'Payload parsed successfully.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: iconColor.withValues(alpha: 0.2),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenInChromeButton(BuildContext context, String url) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.35),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final ok = await BrowserService.openInBrowser(url);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not open $url in Chrome / browser.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Chrome styled badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.public_rounded,
                    color: Color(0xFF1976D2),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Open in Chrome',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchFallbackButton(BuildContext context) {
    final query = item.displayTitle;
    return ElevatedButton.icon(
      onPressed: () async {
        await BrowserService.searchInBrowser(query);
      },
      icon: const Icon(Icons.search_rounded),
      label: Text('Search in Chrome ("$query")'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildDataView(BuildContext context) {
    final data = item.parsedData;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data is Map<String, dynamic>) {
      return Card(
        elevation: 0,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Order Details',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${data.length} fields',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const Divider(height: 24),
              ...data.entries.map((entry) => _buildDetailRow(context, entry.key, entry.value)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          data.toString(),
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String key, dynamic value) {
    String formattedValue;
    bool isClickableUrl = false;

    if (value is Map || value is List) {
      formattedValue = jsonEncode(value);
    } else {
      formattedValue = value?.toString() ?? 'null';
      if (formattedValue.startsWith('http://') || formattedValue.startsWith('https://')) {
        isClickableUrl = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              _formatKey(key),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isClickableUrl
                ? GestureDetector(
                    onTap: () => BrowserService.openInBrowser(formattedValue),
                    child: Text(
                      formattedValue,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : SelectableText(
                    formattedValue,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    // Convert camelCase or snake_case to Title Case
    final buffer = StringBuffer();
    for (int i = 0; i < key.length; i++) {
      final char = key[i];
      if (char == '_' || char == '-') {
        buffer.write(' ');
      } else if (i > 0 && char.toUpperCase() == char && key[i - 1].toLowerCase() == key[i - 1]) {
        buffer.write(' $char');
      } else {
        buffer.write(i == 0 ? char.toUpperCase() : char);
      }
    }
    return buffer.toString();
  }

  Widget _buildRawPayloadSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Raw Payload / Technical Info',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          item.dataType == ScanDataType.encryptedUr
              ? 'UR type: ${item.urType ?? "bytes"} • Fragments: ${item.partsCount}'
              : 'Direct scan data',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181818) : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('JSON Payload:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: item.prettyJson));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied JSON to clipboard')),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'Copy JSON',
                          style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  item.prettyJson,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Raw QR Text:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                SelectableText(
                  item.rawScanned,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

