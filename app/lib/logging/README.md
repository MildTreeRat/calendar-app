# Logger System Documentation

## Overview

This is a production-ready logging system for Flutter/Dart applications that implements several software engineering design patterns for efficiency, maintainability, and extensibility.

## Design Patterns Implemented

### 1. **Singleton Pattern**
The `Logger` class uses the Singleton pattern to ensure only one instance exists throughout the application lifecycle.

```dart
static Logger? _instance;
static Logger get instance => _instance ?? (throw StateError('Logger not initialized'));
```

### 2. **Observer Pattern**
Log observers can subscribe to log events and errors without tight coupling:

```dart
abstract class LogObserver {
  void onLog(LogEntry entry);
  void onError(Object error, StackTrace stackTrace);
}
```

Observers are notified whenever a log entry is created, allowing for flexible output destinations (console, analytics, remote servers, etc.).

### 3. **Factory Pattern**
`LogEntry` uses a factory constructor to create properly initialized log entries:

```dart
factory LogEntry.create({
  required LogLevel level,
  required String message,
  // ... other parameters
}) {
  return LogEntry(
    timestamp: DateTime.now(),
    // ... initialization
  );
}
```

### 4. **Strategy Pattern (Writer Pattern)**
Different log writers implement the `LogWriter` interface, allowing flexible output strategies:

```dart
abstract class LogWriter {
  Future<void> write(LogEntry entry);
  Future<void> writeBatch(List<LogEntry> entries);
  Future<void> flush();
  Future<void> close();
}
```

Current implementations:
- `FileLogWriter`: Writes logs to files with buffering
- Can easily add: `NetworkLogWriter`, `DatabaseLogWriter`, etc.

## Key Features

### Performance Optimizations

1. **Queue-based Batching**
   - Logs are queued in memory
   - Written in batches to reduce I/O operations
   - Configurable batch size (default: 50 entries)

2. **Automatic Flushing**
   - Periodic timer flushes logs every 250ms (configurable)
   - Ensures logs aren't lost while minimizing I/O

3. **Buffer Management**
   - In-memory StringBuffer reduces string concatenation overhead
   - Queue with maximum size prevents memory bloat
   - Automatic old log cleanup (configurable retention period)

### Configuration

```dart
await Logger.initialize(
  config: const LoggerConfig(
    level: LogLevel.debug,           // Minimum log level
    console: true,                   // Enable console output
    queueMax: 10000,                 // Max queue size
    batchSize: 50,                   // Logs per batch
    flushEvery: Duration(milliseconds: 250),
    keepDays: 7,                     // Log retention
    structuredLogging: true,         // JSON vs plain text
  ),
);
```

### Log Levels

1. **TRACE** - Very detailed diagnostic information
2. **DEBUG** - Detailed debugging information
3. **INFO** - General informational messages
4. **WARN** - Warning messages for potentially harmful situations
5. **ERROR** - Error messages with optional stack traces

### Usage Examples

```dart
final logger = Logger.instance;

// Simple logging
logger.info('User logged in');

// With tags
logger.debug('Processing payment', tag: 'PaymentService');

// With metadata
logger.info('Order created',
  tag: 'Orders',
  metadata: {'orderId': '12345', 'amount': 99.99}
);

// Error logging with stack trace
try {
  // risky operation
} catch (e, stack) {
  logger.error('Failed to process order',
    tag: 'Orders',
    error: e,
    stackTrace: stack
  );
}
```

### Structured Logging

When `structuredLogging: true`, logs are output as JSON:

```json
{
  "timestamp": "2025-10-16T21:59:23.570077",
  "level": "info",
  "message": "Application starting",
  "session": "1729113563570",
  "platform": "windows",
  "build": "1.0.0+1",
  "tag": "main"
}
```

When `false`, logs use plain text format:
```
[2025-10-16T21:59:23.570077] [INFO] [main] Application starting
```

## Architecture Benefits

### Extensibility
- Easy to add new log observers (analytics, crash reporting)
- Easy to add new log writers (database, network, cloud)
- Configuration-driven behavior

### Performance
- Asynchronous I/O operations
- Batched writes reduce system calls
- Queue prevents UI blocking
- Automatic buffer management

### Reliability
- Error handling prevents logger from crashing app
- Silent failure for non-critical errors
- Proper cleanup and resource management
- Graceful shutdown with flush

### Maintainability
- Clear separation of concerns
- Single Responsibility Principle
- Open/Closed Principle (open for extension, closed for modification)
- Comprehensive documentation

## File Storage

Logs are stored in:
- **Location**: `{ApplicationDocumentsDirectory}/logs/`
- **Format**: `app_YYYY-MM-DD.log`
- **Retention**: Configurable (default 7 days)
- **Auto-cleanup**: Old logs automatically deleted

## Testing

The logger has been tested with:
- ✅ Multiple log levels
- ✅ Tags and metadata
- ✅ Error and stack trace logging
- ✅ Console output
- ✅ File persistence
- ✅ Batch processing
- ✅ Performance under load

## Session Tracking

Each app session gets:
- Unique session ID
- Platform information
- Build version
- All tracked automatically in every log entry

## Best Practices

1. **Initialize early**: Call `Logger.initialize()` in `main()` before `runApp()`
2. **Use appropriate levels**: Don't use ERROR for warnings
3. **Add context**: Use tags and metadata liberally
4. **Clean shutdown**: Call `Logger.instance.shutdown()` on app exit
5. **Structured logging**: Enable for production environments
6. **Performance**: Logger is designed for high-frequency logging

## Future Enhancements

Potential additions:
- Remote log shipping
- Log aggregation
- Real-time log streaming
- Log search and filtering
- Performance metrics
- Custom log formatters
- Log encryption
