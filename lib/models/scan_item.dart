import 'dart:convert';

enum ScanDataType {
  encryptedUr,
  plainUr,
  directUrl,
  plainJson,
  plainText,
}

class ScanItem {
  final String id;
  final String rawScanned;
  final ScanDataType dataType;
  final bool isDecrypted;
  final String? urType;
  final dynamic parsedData;
  final String? rawJsonString;
  final String? extractedUrl;
  final String? error;
  final DateTime timestamp;
  final int partsCount;

  ScanItem({
    required this.id,
    required this.rawScanned,
    required this.dataType,
    this.isDecrypted = false,
    this.urType,
    this.parsedData,
    this.rawJsonString,
    this.extractedUrl,
    this.error,
    DateTime? timestamp,
    this.partsCount = 1,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get hasUrl => extractedUrl != null && extractedUrl!.trim().isNotEmpty;
  bool get hasError => error != null && error!.isNotEmpty;

  String get displayTitle {
    if (parsedData is Map<String, dynamic>) {
      final map = parsedData as Map<String, dynamic>;
      if (map.containsKey('orderId')) return 'Order #${map['orderId']}';
      if (map.containsKey('id')) return 'ID: ${map['id']}';
      if (map.containsKey('title')) return '${map['title']}';
      if (map.containsKey('name')) return '${map['name']}';
    }
    if (hasUrl) {
      return extractedUrl!;
    }
    if (rawScanned.length > 30) {
      return '${rawScanned.substring(0, 30)}...';
    }
    return rawScanned;
  }

  String get prettyJson {
    if (rawJsonString != null && rawJsonString!.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJsonString!);
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(decoded);
      } catch (_) {
        return rawJsonString!;
      }
    }
    if (parsedData != null) {
      try {
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(parsedData);
      } catch (_) {
        return parsedData.toString();
      }
    }
    return rawScanned;
  }
}

