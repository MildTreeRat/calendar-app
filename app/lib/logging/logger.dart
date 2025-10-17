import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

// ============================================================================
// Enums & Constants
// ============================================================================

enum LogLevel {
  trace(0),
  debug(1),
  info(2),
  warn(3),
  error(4);

  const LogLevel(this.value);
  final int value;

  bool operator >=(LogLevel other) => value >= other.value;
}

// ============================================================================
// Configuration
// ============================================================================

class LoggerConfig {
  final LogLevel level;
  final bool console;
  final int queueMax;
  final int batchSize;
  final Duration flushEvery;
  final int keepDays;
  final bool structuredLogging;

  const LoggerConfig({
    this.level = LogLevel.debug,
    this.console = true,
    this.queueMax = 10000,
    this.batchSize = 50,
    this.flushEvery = const Duration(milliseconds: 250),
    this.keepDays = 7,
    this.structuredLogging = true,
  });
}

// ============================================================================
// Log Entry (Factory Pattern)
// ============================================================================

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;
  final Map<String, dynamic>? metadata;
  final String? error;
  final String? stackTrace;
  final String session;
  final String platform;
  final String build;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.session,
    required this.platform,
    required this.build,
    this.tag,
    this.metadata,
    this.error,
    this.stackTrace,
  });

  factory LogEntry.create({
    required LogLevel level,
    required String message,
    required String session,
    required String platform,
    required String build,
    String? tag,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      session: session,
      platform: platform,
      build: build,
      tag: tag,
      metadata: metadata,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'session': session,
      'platform': platform,
      'build': build,
      if (tag != null) 'tag': tag,
      if (metadata != null) 'metadata': metadata,
      if (error != null) 'error': error,
      if (stackTrace != null) 'stackTrace': stackTrace,
    };
  }

  String toPlainText() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}]');
    buffer.write(' [${level.name.toUpperCase()}]');
    if (tag != null) {
      buffer.write(' [$tag]');
    }
    buffer.write(' $message');
    if (error != null) {
      buffer.write(' | Error: $error');
    }
    return buffer.toString();
  }
}

// ============================================================================
// Observer Pattern - Log Observers
// ============================================================================

abstract class LogObserver {
  void onLog(LogEntry entry);
  void onError(Object error, StackTrace stackTrace);
}

class ConsoleLogObserver implements LogObserver {
  final bool structuredLogging;

  ConsoleLogObserver({this.structuredLogging = true});

  @override
  void onLog(LogEntry entry) {
    if (structuredLogging) {
      // ignore: avoid_print
      print(jsonEncode(entry.toJson()));
    } else {
      // ignore: avoid_print
      print(entry.toPlainText());
    }
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    // ignore: avoid_print
    print('Logger Error: $error\n$stackTrace');
  }
}

// ============================================================================
// Writer Pattern - Log Writers
// ============================================================================

abstract class LogWriter {
  Future<void> write(LogEntry entry);
  Future<void> writeBatch(List<LogEntry> entries);
  Future<void> flush();
  Future<void> close();
}

class FileLogWriter implements LogWriter {
  final String filePath;
  final bool structuredLogging;
  IOSink? _sink;
  final _buffer = StringBuffer();
  bool _isClosed = false;

  FileLogWriter({required this.filePath, this.structuredLogging = true});

  Future<void> open() async {
    if (_sink == null && !_isClosed) {
      _sink = File(filePath).openWrite(mode: FileMode.append);
    }
  }

  @override
  Future<void> write(LogEntry entry) async {
    if (_isClosed) return;
    await open();

    final line = structuredLogging
        ? jsonEncode(entry.toJson())
        : entry.toPlainText();

    _buffer.writeln(line);
  }

  @override
  Future<void> writeBatch(List<LogEntry> entries) async {
    if (_isClosed || entries.isEmpty) return;
    await open();

    for (final entry in entries) {
      final line = structuredLogging
          ? jsonEncode(entry.toJson())
          : entry.toPlainText();
      _buffer.writeln(line);
    }

    await flush();
  }

  @override
  Future<void> flush() async {
    if (_isClosed || _buffer.isEmpty) return;

    final content = _buffer.toString();
    _buffer.clear();

    try {
      _sink?.write(content);
      await _sink?.flush();
    } catch (e) {
      // Silently fail to avoid logging errors in the logger
    }
  }

  @override
  Future<void> close() async {
    _isClosed = true;
    await flush();
    await _sink?.close();
    _sink = null;
  }
}

// ============================================================================
// Singleton Logger with Observer Pattern
// ============================================================================

class Logger {
  static Logger? _instance;
  static Logger get instance =>
      _instance ?? (throw StateError('Logger not initialized'));

  final LoggerConfig _config;
  final String _sessionId;
  final String _platform;
  final String _build;

  final List<LogObserver> _observers = [];
  final List<LogWriter> _writers = [];
  final Queue<LogEntry> _queue = Queue();

  Timer? _flushTimer;
  bool _isShuttingDown = false;

  Logger._({
    required LoggerConfig config,
    required String sessionId,
    required String platform,
    required String build,
  }) : _config = config,
       _sessionId = sessionId,
       _platform = platform,
       _build = build;

  // ============================================================================
  // Initialization (Factory Pattern)
  // ============================================================================

  static Future<Logger> initialize({
    LoggerConfig config = const LoggerConfig(),
  }) async {
    if (_instance != null) {
      return _instance!;
    }

    // Get platform info
    final platform = Platform.operatingSystem;

    // Get build info
    String build = 'unknown';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      build = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      build = 'dev';
    }

    // Generate session ID
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    _instance = Logger._(
      config: config,
      sessionId: sessionId,
      platform: platform,
      build: build,
    );

    await _instance!._setup();
    return _instance!;
  }

  Future<void> _setup() async {
    // Add console observer
    if (_config.console) {
      addObserver(
        ConsoleLogObserver(structuredLogging: _config.structuredLogging),
      );
    }

    // Setup file writer
    try {
      // Use project directory for logs (easier to find and review)
      final logDir = Directory('logs');
      await logDir.create(recursive: true);

      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final logFile = '${logDir.path}/app_$dateStr.log';

      final writer = FileLogWriter(
        filePath: logFile,
        structuredLogging: _config.structuredLogging,
      );
      await writer.open();
      addWriter(writer);

      // Clean old logs
      await _cleanOldLogs(logDir);
    } catch (e, stack) {
      _notifyObserversError(e, stack);
    }

    // Start flush timer
    _flushTimer = Timer.periodic(_config.flushEvery, (_) => _processBatch());
  }

  Future<void> _cleanOldLogs(Directory logDir) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: _config.keepDays));
      await for (final entity in logDir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  // ============================================================================
  // Observer Management
  // ============================================================================

  void addObserver(LogObserver observer) {
    _observers.add(observer);
  }

  void removeObserver(LogObserver observer) {
    _observers.remove(observer);
  }

  void addWriter(LogWriter writer) {
    _writers.add(writer);
  }

  void removeWriter(LogWriter writer) {
    _writers.remove(writer);
  }

  // ============================================================================
  // Logging Methods
  // ============================================================================

  void log(
    LogLevel level,
    String message, {
    String? tag,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!(level >= _config.level) || _isShuttingDown) return;

    final entry = LogEntry.create(
      level: level,
      message: message,
      session: _sessionId,
      platform: _platform,
      build: _build,
      tag: tag,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );

    _enqueue(entry);
  }

  void trace(String message, {String? tag, Map<String, dynamic>? metadata}) {
    log(LogLevel.trace, message, tag: tag, metadata: metadata);
  }

  void debug(String message, {String? tag, Map<String, dynamic>? metadata}) {
    log(LogLevel.debug, message, tag: tag, metadata: metadata);
  }

  void info(String message, {String? tag, Map<String, dynamic>? metadata}) {
    log(LogLevel.info, message, tag: tag, metadata: metadata);
  }

  void warn(
    String message, {
    String? tag,
    Map<String, dynamic>? metadata,
    Object? error,
  }) {
    log(LogLevel.warn, message, tag: tag, metadata: metadata, error: error);
  }

  void error(
    String message, {
    String? tag,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.error,
      message,
      tag: tag,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // ============================================================================
  // Queue Management
  // ============================================================================

  void _enqueue(LogEntry entry) {
    if (_queue.length >= _config.queueMax) {
      _queue.removeFirst();
    }
    _queue.add(entry);
    _notifyObservers(entry);

    if (_queue.length >= _config.batchSize) {
      _processBatch();
    }
  }

  void _notifyObservers(LogEntry entry) {
    for (final observer in _observers) {
      try {
        observer.onLog(entry);
      } catch (e, stack) {
        // Prevent observer errors from breaking logging
        _notifyObserversError(e, stack);
      }
    }
  }

  void _notifyObserversError(Object error, StackTrace stackTrace) {
    for (final observer in _observers) {
      try {
        observer.onError(error, stackTrace);
      } catch (_) {
        // Ignore errors in error handlers
      }
    }
  }

  Future<void> _processBatch() async {
    if (_queue.isEmpty || _isShuttingDown) return;

    final batch = <LogEntry>[];
    while (_queue.isNotEmpty && batch.length < _config.batchSize) {
      batch.add(_queue.removeFirst());
    }

    for (final writer in _writers) {
      try {
        await writer.writeBatch(batch);
      } catch (e, stack) {
        _notifyObserversError(e, stack);
      }
    }
  }

  // ============================================================================
  // Shutdown
  // ============================================================================

  Future<void> shutdown() async {
    _isShuttingDown = true;
    _flushTimer?.cancel();

    await _processBatch();

    for (final writer in _writers) {
      try {
        await writer.close();
      } catch (e, stack) {
        _notifyObserversError(e, stack);
      }
    }

    _writers.clear();
    _observers.clear();
    _instance = null;
  }
}
