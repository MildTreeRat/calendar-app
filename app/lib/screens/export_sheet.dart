import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database.dart';
import '../repositories/calendars_repository.dart';
import '../services/ics_export_service.dart';
import '../logging/logger.dart';

/// Modal bottom sheet for exporting calendars to ICS format
class ExportSheet extends StatefulWidget {
  final AppDatabase database;
  final String userId;

  const ExportSheet({
    super.key,
    required this.database,
    required this.userId,
  });

  /// Show the export sheet as a modal
  static Future<void> show(BuildContext context, AppDatabase database, String userId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExportSheet(
        database: database,
        userId: userId,
      ),
    );
  }

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  final Logger _logger = Logger.instance;
  late final CalendarsRepository _calendarsRepo;
  late final IcsExportService _exportService;

  List<Calendar> _calendars = [];
  Set<String> _selectedCalendarIds = {};
  bool _loading = true;
  bool _exporting = false;
  String? _exportedFilePath;
  String? _error;

  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _calendarsRepo = CalendarsRepository(db: widget.database);
    _exportService = IcsExportService(db: widget.database);
    _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    try {
      final calendars = await _calendarsRepo.getVisibleCalendars(widget.userId);
      setState(() {
        _calendars = calendars;
        _selectedCalendarIds = calendars.map((c) => c.id).toSet();
        _loading = false;
      });
    } catch (e, st) {
      _logger.error('Failed to load calendars', tag: 'export.load', error: e, stackTrace: st);
      setState(() {
        _error = 'Failed to load calendars: $e';
        _loading = false;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = _dateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now.add(const Duration(days: 90)),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  Future<void> _exportCalendar() async {
    if (_selectedCalendarIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one calendar')),
      );
      return;
    }

    setState(() {
      _exporting = true;
      _error = null;
      _exportedFilePath = null;
    });

    try {
      final calendarNames = _calendars
          .where((c) => _selectedCalendarIds.contains(c.id))
          .map((c) => c.name)
          .join(', ');

      final filePath = await _exportService.exportToIcs(
        calendarIds: _selectedCalendarIds.toList(),
        startMs: _dateRange?.start.millisecondsSinceEpoch,
        endMs: _dateRange?.end.millisecondsSinceEpoch,
        calName: calendarNames,
      );

      setState(() {
        _exportedFilePath = filePath;
        _exporting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${filePath.split(Platform.pathSeparator).last}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, st) {
      _logger.error('Export failed', tag: 'export.error', error: e, stackTrace: st);
      setState(() {
        _error = 'Export failed: $e';
        _exporting = false;
      });
    }
  }

  void _copyPath() {
    if (_exportedFilePath != null) {
      Clipboard.setData(ClipboardData(text: _exportedFilePath!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Path copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    const Icon(Icons.file_download, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Export Calendar',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _error = null;
                                        _loading = true;
                                      });
                                      _loadCalendars();
                                    },
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(24),
                            children: [
                              // Calendar Selection
                              const Text(
                                'Select Calendars',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_calendars.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    'No visible calendars found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              else
                                ..._calendars.map((calendar) {
                                  final isSelected = _selectedCalendarIds.contains(calendar.id);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedCalendarIds.add(calendar.id);
                                        } else {
                                          _selectedCalendarIds.remove(calendar.id);
                                        }
                                      });
                                    },
                                    title: Text(calendar.name),
                                    subtitle: Text(
                                      '${_selectedCalendarIds.contains(calendar.id) ? "Selected" : "Not selected"}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    secondary: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: calendar.color != null
                                            ? Color(int.parse(calendar.color!.replaceFirst('#', '0xFF')))
                                            : Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  );
                                }),

                              const SizedBox(height: 24),

                              // Date Range
                              const Text(
                                'Date Range (Optional)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _pickDateRange,
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  _dateRange == null
                                      ? 'All dates'
                                      : '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                  alignment: Alignment.centerLeft,
                                ),
                              ),
                              if (_dateRange != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _dateRange = null;
                                      });
                                    },
                                    icon: const Icon(Icons.clear, size: 16),
                                    label: const Text('Clear date range'),
                                  ),
                                ),

                              const SizedBox(height: 32),

                              // Export Button
                              FilledButton.icon(
                                onPressed: _exporting ? null : _exportCalendar,
                                icon: _exporting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.download),
                                label: Text(_exporting ? 'Exporting...' : 'Export to ICS'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  textStyle: const TextStyle(fontSize: 16),
                                ),
                              ),

                              // Export Success Actions
                              if (_exportedFilePath != null) ...[
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.green[700]),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Export Complete',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _exportedFilePath!.split(Platform.pathSeparator).last,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: _copyPath,
                                            icon: const Icon(Icons.copy, size: 16),
                                            label: const Text('Copy Path'),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
