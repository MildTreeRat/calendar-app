import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database.dart';
import '../logging/logger.dart';
import '../models/ics_export_event.dart';

/// Service for exporting events to ICS format
class IcsExportService {
  final AppDatabase _db;
  final Logger _logger;
  late final ffi.DynamicLibrary _lib;
  late final ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>) _icsExportFfi;
  late final void Function(ffi.Pointer<Utf8>) _icsExportFreeString;

  IcsExportService({
    required AppDatabase db,
  })  : _db = db,
        _logger = Logger.instance {
    _initFfi();
  }

  /// Initialize FFI bindings to Rust library
  void _initFfi() {
    try {
      // Load the dynamic library
      // The DLL/SO/DYLIB should be bundled with the app via CMakeLists.txt
      if (Platform.isWindows) {
        _lib = ffi.DynamicLibrary.open('calendar_core.dll');
      } else if (Platform.isLinux) {
        _lib = ffi.DynamicLibrary.open('libcalendar_core.so');
      } else if (Platform.isMacOS) {
        _lib = ffi.DynamicLibrary.open('libcalendar_core.dylib');
      } else {
        throw UnsupportedError('ICS export not supported on ${Platform.operatingSystem}');
      }

      // Bind FFI functions
      _icsExportFfi = _lib.lookupFunction<
          ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>),
          ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>)>('ics_export_ffi');

      _icsExportFreeString = _lib.lookupFunction<
          ffi.Void Function(ffi.Pointer<Utf8>),
          void Function(ffi.Pointer<Utf8>)>('ics_export_free_string');

      _logger.info('FFI initialized', tag: 'ics.export.init');
    } catch (e, st) {
      _logger.error('Failed to initialize FFI', tag: 'ics.export.init', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Export events to ICS file
  ///
  /// [calendarIds] - List of calendar IDs to export (empty = all calendars)
  /// [startMs] - Start of time range (UTC millis), null = no start bound
  /// [endMs] - End of time range (UTC millis), null = no end bound
  /// [prodId] - PRODID for the ICS file (e.g., "-//MyApp//Calendar 1.0//EN")
  /// [calName] - Calendar name for X-WR-CALNAME property
  ///
  /// Returns the absolute path to the created ICS file
  Future<String> exportToIcs({
    List<String> calendarIds = const [],
    int? startMs,
    int? endMs,
    String prodId = '-//Calendar App//Calendar 1.0//EN',
    required String calName,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logger.info(
      'ICS export started',
      tag: 'ics.export.start',
      metadata: {
        'calendar_ids': calendarIds,
        'start_ms': startMs,
        'end_ms': endMs,
        'cal_name': calName,
      },
    );

    try {
      // Query events from database
      final events = await _queryEvents(
        calendarIds: calendarIds,
        startMs: startMs,
        endMs: endMs,
      );

      _logger.info(
        'Queried ${events.length} events',
        tag: 'ics.export.query',
        metadata: {'count': events.length},
      );

      // Build export DTOs
      final exportEvents = await _buildExportEvents(events);

      // Create export request
      final request = IcsExportRequest(
        prodId: prodId,
        calName: calName,
        events: exportEvents,
      );

      // Call Rust FFI
      final jsonRequest = jsonEncode(request.toJson());
      final icsContent = await _callRustExport(jsonRequest);

      // Save to file
      final filePath = await _saveIcsFile(
        content: icsContent,
        calName: calName,
        startMs: startMs,
        endMs: endMs,
      );

      stopwatch.stop();
      _logger.info(
        'ICS export completed',
        tag: 'ics.export.done',
        metadata: {
          'file_path': filePath,
          'event_count': events.length,
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );

      return filePath;
    } catch (e, st) {
      stopwatch.stop();
      _logger.error(
        'ICS export failed',
        tag: 'ics.export.error',
        error: e,
        stackTrace: st,
        metadata: {
          'calendar_ids': calendarIds,
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );
      rethrow;
    }
  }

  /// Query events from database with optional filters
  Future<List<Event>> _queryEvents({
    required List<String> calendarIds,
    int? startMs,
    int? endMs,
  }) async {
    final query = _db.select(_db.events);

    // Filter by calendar IDs
    if (calendarIds.isNotEmpty) {
      query.where((e) => e.calendarId.isIn(calendarIds));
    }

    // Filter by time range
    if (startMs != null) {
      query.where((e) => e.startMs.isBiggerOrEqualValue(startMs));
    }
    if (endMs != null) {
      query.where((e) => e.endMs.isSmallerOrEqualValue(endMs));
    }

    // Order by start time
    query.orderBy([(_) => OrderingTerm.asc(_db.events.startMs)]);

    return query.get();
  }

  /// Build ICS export event DTOs from database events
  Future<List<IcsExportEvent>> _buildExportEvents(List<Event> events) async {
    final exportEvents = <IcsExportEvent>[];

    for (final event in events) {
      // Get calendar name
      final calendar = await (_db.select(_db.calendars)
            ..where((c) => c.id.equals(event.calendarId)))
          .getSingleOrNull();

      // Parse exdates/rdates from JSON
      List<int>? exdates;
      if (event.exdates != null && event.exdates!.isNotEmpty) {
        try {
          exdates = (jsonDecode(event.exdates!) as List).cast<int>();
        } catch (e) {
          _logger.warn(
            'Failed to parse exdates',
            tag: 'ics.export.parse',
            metadata: {'event_id': event.id, 'exdates': event.exdates},
          );
        }
      }

      List<int>? rdates;
      if (event.rdates != null && event.rdates!.isNotEmpty) {
        try {
          rdates = (jsonDecode(event.rdates!) as List).cast<int>();
        } catch (e) {
          _logger.warn(
            'Failed to parse rdates',
            tag: 'ics.export.parse',
            metadata: {'event_id': event.id, 'rdates': event.rdates},
          );
        }
      }

      exportEvents.add(IcsExportEvent(
        id: event.id,
        uid: event.uid,
        calendarName: calendar?.name,
        title: event.title,
        description: event.description,
        location: event.location,
        startMs: event.startMs,
        endMs: event.endMs,
        tzid: event.tzid,
        allDay: event.allDay,
        rrule: event.rrule,
        exdates: exdates,
        rdates: rdates,
      ));
    }

    return exportEvents;
  }

  /// Call Rust FFI to generate ICS content
  Future<String> _callRustExport(String jsonRequest) async {
    return Future(() {
      // Convert Dart string to C string
      final jsonPtr = jsonRequest.toNativeUtf8();

      try {
        // Call FFI
        final resultPtr = _icsExportFfi(jsonPtr);

        // Check for null (error case)
        if (resultPtr.address == 0) {
          throw Exception('Rust export failed (returned null pointer)');
        }

        try {
          // Convert C string to Dart string
          return resultPtr.toDartString();
        } finally {
          // Free the C string
          _icsExportFreeString(resultPtr);
        }
      } finally {
        // Free the input C string
        malloc.free(jsonPtr);
      }
    });
  }

  /// Save ICS content to file with timestamped filename
  Future<String> _saveIcsFile({
    required String content,
    required String calName,
    int? startMs,
    int? endMs,
  }) async {
    // Get documents directory
    final dir = await getApplicationDocumentsDirectory();
    final icsDir = Directory('${dir.path}/exports');
    await icsDir.create(recursive: true);

    // Generate filename: calendar-export_20240315-1430_start_end.ics
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    final sanitizedCalName = calName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '-');

    String filename = 'calendar-export_${timestamp}';
    if (startMs != null) {
      final startDate = DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true);
      filename += '_${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
    }
    if (endMs != null) {
      final endDate = DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true);
      filename += '_${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
    }
    filename += '_${sanitizedCalName}.ics';

    // Write file
    final file = File('${icsDir.path}/$filename');
    await file.writeAsString(content);

    return file.path;
  }
}
