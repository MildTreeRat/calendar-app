# Log Level Configuration Guide

## Quick Reference

### How to Change Log Level (ONE LINE!)

In `main.dart`, change the `level` parameter:

```dart
await Logger.initialize(
  config: const LoggerConfig(
    level: LogLevel.info, // ← Change this line!
    console: true,
    structuredLogging: false,
    keepDays: 7,
  ),
);
```

## Available Log Levels

### LogLevel.trace (0)
**Shows**: Everything
**Use for**: Development, detailed debugging
```dart
level: LogLevel.trace
```
**Output**: TRACE, DEBUG, INFO, WARN, ERROR

---

### LogLevel.debug (1)
**Shows**: Debug and above
**Use for**: Development, general debugging
```dart
level: LogLevel.debug
```
**Output**: DEBUG, INFO, WARN, ERROR
**Filters out**: TRACE

---

### LogLevel.info (2) ⭐ **Recommended for Production**
**Shows**: Important information and errors
**Use for**: Production environments
```dart
level: LogLevel.info
```
**Output**: INFO, WARN, ERROR
**Filters out**: TRACE, DEBUG

---

### LogLevel.warn (3)
**Shows**: Warnings and errors only
**Use for**: Production with minimal logging
```dart
level: LogLevel.warn
```
**Output**: WARN, ERROR
**Filters out**: TRACE, DEBUG, INFO

---

### LogLevel.error (4)
**Shows**: Errors only
**Use for**: Production with error-only logging
```dart
level: LogLevel.error
```
**Output**: ERROR
**Filters out**: TRACE, DEBUG, INFO, WARN

## Log File Locations

### Windows
```
C:\Users\{username}\Documents\logs\app_YYYY-MM-DD.log
```

### macOS
```
~/Library/Application Support/logs/app_YYYY-MM-DD.log
```

### Linux
```
~/.local/share/logs/app_YYYY-MM-DD.log
```

### Android
```
/data/data/{package_name}/app_flutter/logs/app_YYYY-MM-DD.log
```

### iOS
```
{Application_Documents_Directory}/logs/app_YYYY-MM-DD.log
```

## Other Configuration Options

```dart
const LoggerConfig({
  level: LogLevel.info,           // Minimum log level
  console: true,                  // Show in console (true/false)
  structuredLogging: false,       // JSON format (true) or plain text (false)
  keepDays: 7,                    // How many days to keep logs
  queueMax: 10000,                // Max logs in memory queue
  batchSize: 50,                  // Logs per batch write
  flushEvery: Duration(milliseconds: 250), // Auto-flush interval
});
```

## Performance Impact by Log Level

| Level | Performance | Use Case | Logs/Second* |
|-------|-------------|----------|--------------|
| TRACE | Highest Impact | Development only | 1000+ |
| DEBUG | High Impact | Development | 500-1000 |
| INFO | Low Impact | Production | 100-500 |
| WARN | Very Low | Production | 10-100 |
| ERROR | Minimal | Always | 0-10 |

*Approximate values, depends on app complexity

## Best Practices

### Development
```dart
level: LogLevel.trace,  // See everything
console: true,          // Show in console
structuredLogging: false, // Easier to read
```

### Testing
```dart
level: LogLevel.debug,  // Skip trace noise
console: true,
structuredLogging: false,
```

### Production
```dart
level: LogLevel.info,   // Important events only
console: false,         // No console spam
structuredLogging: true, // JSON for log aggregation
keepDays: 30,           // Keep longer for analysis
```

### Production (Minimal)
```dart
level: LogLevel.error,  // Errors only
console: false,
structuredLogging: true,
keepDays: 90,
```

## Quick Test

After changing the log level, you can verify it's working by checking:

1. **Console output** - Should only show logs at or above your level
2. **Log files** - Check `Documents/logs/app_*.log`
3. **Performance** - Higher levels = less logging = better performance

## Finding Your Log Files

### PowerShell (Windows)
```powershell
explorer "$env:USERPROFILE\Documents\logs"
```

### Terminal (macOS/Linux)
```bash
open ~/Library/Application\ Support/logs  # macOS
xdg-open ~/.local/share/logs              # Linux
```

### View logs in real-time
```powershell
# Windows
Get-Content "$env:USERPROFILE\Documents\logs\app_$(Get-Date -Format yyyy-MM-dd).log" -Wait

# macOS/Linux
tail -f ~/Library/Application\ Support/logs/app_$(date +%Y-%m-%d).log
```
