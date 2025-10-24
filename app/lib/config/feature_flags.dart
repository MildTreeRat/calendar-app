import 'dart:convert';
import 'package:flutter/services.dart';

/// Feature flags loader and accessor
class FeatureFlags {
  static FeatureFlags? _instance;
  static FeatureFlags get instance => _instance ?? (throw StateError('FeatureFlags not initialized'));

  final Map<String, dynamic> _flags;

  FeatureFlags._(this._flags);

  /// Initialize feature flags from JSON file
  static Future<FeatureFlags> initialize() async {
    if (_instance != null) {
      return _instance!;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/config/feature_flags.json');
      final flags = jsonDecode(jsonString) as Map<String, dynamic>;
      _instance = FeatureFlags._(flags);
      return _instance!;
    } catch (e) {
      // If file doesn't exist or is invalid, use defaults
      _instance = FeatureFlags._({
        'cloudSync': false,
        'autoSync': false,
        'debugLogging': true,
        'seedData': true,
      });
      return _instance!;
    }
  }

  /// Check if cloud sync is enabled
  bool get cloudSync => _flags['cloudSync'] as bool? ?? false;

  /// Check if auto-sync is enabled
  bool get autoSync => _flags['autoSync'] as bool? ?? false;

  /// Check if debug logging is enabled
  bool get debugLogging => _flags['debugLogging'] as bool? ?? true;

  /// Check if seed data should be inserted
  bool get seedData => _flags['seedData'] as bool? ?? true;

  /// Get a flag value by key
  dynamic getFlag(String key) => _flags[key];

  /// Check if a flag exists and is true
  bool isEnabled(String key) => _flags[key] as bool? ?? false;

  /// Get all flags
  Map<String, dynamic> get all => Map.unmodifiable(_flags);
}
