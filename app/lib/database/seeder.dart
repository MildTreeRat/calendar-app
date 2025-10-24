import 'package:drift/drift.dart';
import 'database.dart';
import '../logging/logger.dart';
import '../utils/id_generator.dart';

/// Seeder for populating initial database data
class Seeder {
  final AppDatabase _db;
  final Logger _logger;

  Seeder({
    required AppDatabase db,
  })  : _db = db,
        _logger = Logger.instance;

  /// Run seeder if database is empty
  Future<void> runIfEmpty() async {
    final userCount = await _db.select(_db.users).get().then((rows) => rows.length);

    if (userCount > 0) {
      _logger.debug('Database not empty, skipping seed', tag: 'seed.run');
      return;
    }

    _logger.info('Seeding database with initial data', tag: 'seed.run');

    await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Create default user
      final userId = IdGenerator.generateUlid();
      await _db.into(_db.users).insert(UsersCompanion(
            id: Value(userId),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: const Value('{}'),
          ));
      _logger.debug('Created default user', tag: 'seed.user', metadata: {'user_id': userId});

      // Create user profile
      await _db.into(_db.userProfiles).insert(UserProfilesCompanion(
            userId: Value(userId),
            displayName: const Value('Default User'),
            email: Value('user@local'),
            tzid: const Value('UTC'),
            paletteId: const Value.absent(),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: const Value('{}'),
          ));
      _logger.debug('Created user profile', tag: 'seed.profile', metadata: {'user_id': userId});

      // Create default color palette
      final paletteId = IdGenerator.generateUlid();
      await _db.into(_db.colorPalettes).insert(ColorPalettesCompanion(
            id: Value(paletteId),
            userId: Value(userId),
            name: const Value('Default Colors'),
            shareCode: const Value.absent(),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: const Value('{}'),
          ));
      _logger.debug('Created color palette', tag: 'seed.palette', metadata: {'palette_id': paletteId});

      // Add default colors to palette
      final colors = [
        '#FF5252', // Red
        '#FF6E40', // Deep Orange
        '#FFD740', // Amber
        '#69F0AE', // Green
        '#40C4FF', // Light Blue
        '#E040FB', // Purple
      ];

      for (var i = 0; i < colors.length; i++) {
        final colorId = IdGenerator.generateUlid();
        await _db.into(_db.paletteColors).insert(PaletteColorsCompanion(
              id: Value(colorId),
              paletteId: Value(paletteId),
              ordinal: Value(i),
              hex: Value(colors[i]),
              createdAt: Value(now),
              updatedAt: Value(now),
            ));
      }
      _logger.debug('Added ${colors.length} colors to palette', tag: 'seed.colors', metadata: {'count': colors.length});

      // Update user profile with default palette
      await (_db.update(_db.userProfiles)..where((t) => t.userId.equals(userId))).write(
            UserProfilesCompanion(
              paletteId: Value(paletteId),
              updatedAt: Value(now),
            ),
          );

      // Create default local account
      final accountId = IdGenerator.generateUlid();
      await _db.into(_db.accounts).insert(AccountsCompanion(
            id: Value(accountId),
            userId: Value(userId),
            provider: const Value('local'),
            subject: Value('local:$userId'),
            label: const Value('Local Device'),
            syncToken: const Value.absent(),
            lastSyncMs: const Value.absent(),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: const Value('{}'),
          ));
      _logger.debug('Created local account', tag: 'seed.account', metadata: {'account_id': accountId});

      // Create "Planning" calendar
      final calendarId = IdGenerator.generateUlid();
      await _db.into(_db.calendars).insert(CalendarsCompanion(
            id: Value(calendarId),
            accountId: Value(accountId),
            userId: Value(userId),
            name: const Value('Planning'),
            color: Value(colors[4]), // Light Blue
            source: const Value('local'),
            externalId: const Value.absent(),
            readOnly: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: const Value('{}'),
          ));
      _logger.debug('Created Planning calendar', tag: 'seed.calendar', metadata: {'calendar_id': calendarId});

      // Create calendar membership
      await _db.into(_db.calendarMemberships).insert(CalendarMembershipsCompanion(
            userId: Value(userId),
            calendarId: Value(calendarId),
            visible: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));
      _logger.debug('Created calendar membership', tag: 'seed.membership');

      // Create sample "Welcome" event (tomorrow at 10 AM)
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final eventStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);
      final eventEnd = eventStart.add(const Duration(hours: 1));

      final eventId = IdGenerator.generateUlid();
      await _db.into(_db.events).insert(EventsCompanion(
            id: Value(eventId),
            calendarId: Value(calendarId),
            uid: Value('welcome-event-$eventId'),
            title: const Value('Welcome to Calendar App!'),
            description: const Value('This is a sample event to get you started. Edit or delete me!'),
            location: const Value.absent(),
            startMs: Value(eventStart.millisecondsSinceEpoch),
            endMs: Value(eventEnd.millisecondsSinceEpoch),
            tzid: const Value('UTC'),
            allDay: const Value(false),
            rrule: const Value.absent(),
            exdates: const Value.absent(),
            rdates: const Value.absent(),
            createdAt: Value(now),
            updatedAt: Value(now),
            metadata: const Value('{}'),
          ));
      _logger.debug('Created welcome event', tag: 'seed.event', metadata: {
        'event_id': eventId,
        'start_ms': eventStart.millisecondsSinceEpoch,
      });
    });

    _logger.info('Database seeding completed successfully', tag: 'seed.run');
  }
}
