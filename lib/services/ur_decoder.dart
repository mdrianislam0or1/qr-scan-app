import 'dart:typed_data';
import 'package:bc_ur_dart/bc_ur_dart.dart';

/// Dart implementation of URDecoder matching the @ngraveio/bc-ur API
class URDecoder {
  UR _ur = UR();

  /// Feed each scanned QR code part into the decoder
  bool receivePart(String scannedText) {
    try {
      final trimmed = scannedText.trim();
      return _ur.read(trimmed);
    } catch (e) {
      return false;
    }
  }

  /// Check if all fragments are received or single UR is complete
  bool isComplete() => _ur.isComplete;

  /// Returns the completed UR object
  UR resultUR() => _ur;

  /// Progress from 0.0 to 1.0
  double getProgress() {
    if (_ur.isComplete) return 1.0;
    if (_ur.expectedPartIndexes.isEmpty) return 0.0;
    return _ur.receivedPartIndexes.length / _ur.expectedPartIndexes.length;
  }

  /// Number of unique parts received so far
  int get receivedPartsCount => _ur.receivedPartIndexes.length;

  /// Total expected parts count
  int get expectedPartsCount => _ur.expectedPartIndexes.length;

  /// Resets the decoder state for a new scan
  void reset() {
    _ur = UR();
  }

  /// Helper to extract raw binary bytes from resultUR().decodeCBOR()
  /// as done in:
  /// const encryptedPayload = resultUR.decodeCBOR(); // Raw binary bytes
  static Uint8List extractCBORBytes(UR ur) {
    try {
      final cborValue = ur.decodeCBOR();
      if (cborValue is CborBytes) {
        return Uint8List.fromList(cborValue.bytes);
      } else if (cborValue is CborList) {
        final bytes = <int>[];
        for (final item in cborValue) {
          if (item is CborSmallInt) {
            bytes.add(item.value);
          } else if (item is CborInt) {
            bytes.add(item.toInt());
          }
        }
        if (bytes.isNotEmpty) {
          return Uint8List.fromList(bytes);
        }
      }
    } catch (_) {
      // Fallback to raw payload if cbor decode fails
    }
    return ur.payload;
  }
}
