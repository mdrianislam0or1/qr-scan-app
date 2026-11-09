import 'package:flutter/material.dart';
import '../models/scan_item.dart';
import '../services/browser_service.dart';
import 'result_screen.dart';

class HistoryScreen extends StatelessWidget {
  final List<ScanItem> history;
  final VoidCallback onClear;

  const HistoryScreen({
    super.key,
    required this.history,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        elevation: 0,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear history',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Scan History?'),
                    content: const Text('All previous scans will be removed.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          onClear();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No scan history yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Scanned QR codes will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = history[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: item.hasUrl
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.green.withValues(alpha: 0.15),
                      child: Icon(
                        item.hasUrl ? Icons.public_rounded : Icons.lock_open_rounded,
                        color: item.hasUrl ? Colors.blueAccent : Colors.green,
                      ),
                    ),
                    title: Text(
                      item.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        if (item.hasUrl)
                          Text(
                            item.extractedUrl!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                          )
                        else
                          Text(
                            item.dataType == ScanDataType.encryptedUr ? 'Encrypted BC-UR' : 'Plain QR',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(item.timestamp),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    trailing: item.hasUrl
                        ? IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, color: Colors.blueAccent),
                            tooltip: 'Open in Chrome',
                            onPressed: () => BrowserService.openInBrowser(item.extractedUrl!),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ResultScreen(item: item)),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} • ${dt.day}/${dt.month}/${dt.year}';
  }
}
