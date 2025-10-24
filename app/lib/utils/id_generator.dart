import 'dart:math';

/// Generates ULIDs (Universally Unique Lexicographically Sortable Identifiers)
/// Format: 26 characters (10 timestamp + 16 random)
/// Example: 01ARZ3NDEKTSV4RRFFQ69G5FAV
class IdGenerator {
  static const String _encodingChars = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static final Random _random = Random.secure();

  /// Generate a new ULID string
  static String generateUlid() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return _encodeTimestamp(timestamp) + _encodeRandom();
  }

  /// Encode timestamp (48 bits) as 10-character base32 string
  static String _encodeTimestamp(int timestamp) {
    final buffer = StringBuffer();
    var value = timestamp;

    for (var i = 0; i < 10; i++) {
      buffer.write(_encodingChars[value % 32]);
      value ~/= 32;
    }

    return buffer.toString().split('').reversed.join();
  }

  /// Encode 80 bits of randomness as 16-character base32 string
  static String _encodeRandom() {
    final buffer = StringBuffer();

    for (var i = 0; i < 16; i++) {
      buffer.write(_encodingChars[_random.nextInt(32)]);
    }

    return buffer.toString();
  }

  /// Check if a string is a valid ULID format (26 chars, valid charset)
  static bool isValidUlid(String value) {
    if (value.length != 26) return false;

    final validChars = RegExp(r'^[' + _encodingChars + r']+$');
    return validChars.hasMatch(value);
  }

  /// Extract timestamp from ULID
  static DateTime? parseTimestamp(String ulid) {
    if (!isValidUlid(ulid)) return null;

    final timestampPart = ulid.substring(0, 10);
    var value = 0;

    for (var i = 0; i < timestampPart.length; i++) {
      value = value * 32 + _encodingChars.indexOf(timestampPart[i]);
    }

    return DateTime.fromMillisecondsSinceEpoch(value);
  }
}
