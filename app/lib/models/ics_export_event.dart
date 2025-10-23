/// Event DTO for ICS export
///
/// Matches the Rust EventDto structure exactly.
/// All timestamps are UTC milliseconds since epoch.
class IcsExportEvent {
  final String id;
  final String? uid;
  final String? calendarName;
  final String title;
  final String? description;
  final String? location;
  final int startMs;
  final int endMs;
  final String? tzid;
  final bool allDay;
  final String? rrule;
  final List<int>? exdates;
  final List<int>? rdates;

  const IcsExportEvent({
    required this.id,
    this.uid,
    this.calendarName,
    required this.title,
    this.description,
    this.location,
    required this.startMs,
    required this.endMs,
    this.tzid,
    required this.allDay,
    this.rrule,
    this.exdates,
    this.rdates,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (uid != null) 'uid': uid,
        if (calendarName != null) 'calendar_name': calendarName,
        'title': title,
        if (description != null) 'description': description,
        if (location != null) 'location': location,
        'start_ms': startMs,
        'end_ms': endMs,
        if (tzid != null) 'tzid': tzid,
        'all_day': allDay,
        if (rrule != null) 'rrule': rrule,
        if (exdates != null) 'exdates': exdates,
        if (rdates != null) 'rdates': rdates,
      };
}

/// Export request wrapper
class IcsExportRequest {
  final String prodId;
  final String calName;
  final List<IcsExportEvent> events;

  const IcsExportRequest({
    required this.prodId,
    required this.calName,
    required this.events,
  });

  Map<String, dynamic> toJson() => {
        'prod_id': prodId,
        'cal_name': calName,
        'events': events.map((e) => e.toJson()).toList(),
      };
}
