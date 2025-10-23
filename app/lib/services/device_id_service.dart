import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../logging/logger.dart';

// ============================================================================
// DeviceIdService - Manages persistent device identity
// ============================================================================

class DeviceIdService {
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'device_id';
  static const _uuid = Uuid();

  static String? _cachedDeviceId;

  /// Get or generate a persistent device ID
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final logger = Logger.instance;

    try {
      // Try to read existing device ID
      String? deviceId = await _storage.read(key: _deviceIdKey);

      if (deviceId == null) {
        // Generate new device ID
        deviceId = _uuid.v4();
        await _storage.write(key: _deviceIdKey, value: deviceId);
        logger.info('Generated new device ID', tag: 'DeviceId', metadata: {
          'device_id': deviceId,
        });
      } else {
        logger.debug('Loaded existing device ID', tag: 'DeviceId');
      }

      _cachedDeviceId = deviceId;
      return deviceId;
    } catch (e, stack) {
      logger.error('Failed to get/create device ID',
        tag: 'DeviceId',
        error: e,
        stackTrace: stack,
      );

      // Fallback to in-memory ID (not ideal but prevents app crash)
      if (_cachedDeviceId == null) {
        _cachedDeviceId = _uuid.v4();
        logger.warn('Using in-memory device ID (not persisted)',
          tag: 'DeviceId',
          metadata: {'device_id': _cachedDeviceId},
        );
      }

      return _cachedDeviceId!;
    }
  }

  /// Clear the device ID (use for testing or account reset)
  static Future<void> clearDeviceId() async {
    try {
      await _storage.delete(key: _deviceIdKey);
      _cachedDeviceId = null;
      Logger.instance.info('Cleared device ID', tag: 'DeviceId');
    } catch (e, stack) {
      Logger.instance.error('Failed to clear device ID',
        tag: 'DeviceId',
        error: e,
        stackTrace: stack,
      );
    }
  }
}
