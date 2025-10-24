import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../database/database.dart';

class DatabaseDemoScreen extends StatefulWidget {
  final AppDatabase database;

  const DatabaseDemoScreen({
    super.key,
    required this.database,
  });

  @override
  State<DatabaseDemoScreen> createState() => _DatabaseDemoScreenState();
}

class _DatabaseDemoScreenState extends State<DatabaseDemoScreen> {
  late AppDatabase database;
  List<User> users = [];
  List<Calendar> calendars = [];
  List<Event> events = [];
  List<ColorPalette> palettes = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    database = widget.database;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    final loadedUsers = await database.select(database.users).get();
    final loadedCalendars = await database.select(database.calendars).get();
    final loadedEvents = await database.select(database.events).get();
    final loadedPalettes = await database.select(database.colorPalettes).get();

    setState(() {
      users = loadedUsers;
      calendars = loadedCalendars;
      events = loadedEvents;
      palettes = loadedPalettes;
      isLoading = false;
    });
  }

  Future<void> _addTestEvent() async {
    final calendar = calendars.first;
    final now = DateTime.now().millisecondsSinceEpoch;

    await database.into(database.events).insert(EventsCompanion.insert(
      id: '${DateTime.now().millisecondsSinceEpoch}_event',
      calendarId: calendar.id,
      uid: Value('test-event-${DateTime.now().millisecondsSinceEpoch}'),
      title: 'Test Event ${events.length + 1}',
      startMs: now,
      endMs: now + 3600000, // +1 hour
      createdAt: now,
      updatedAt: now,
    ));

    await _loadData();
  }

  @override
  void dispose() {
    database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Users',
            users.length.toString(),
            Icons.person,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Calendars',
            calendars.length.toString(),
            Icons.calendar_today,
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Events',
            events.length.toString(),
            Icons.event,
            Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Color Palettes',
            palettes.length.toString(),
            Icons.palette,
            Colors.purple,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildEventsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTestEvent,
        icon: const Icon(Icons.add),
        label: const Text('Add Test Event'),
      ),
    );
  }

  Widget _buildSection(String title, String count, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        trailing: Text(
          count,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    if (events.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No events yet. Tap the button to add a test event!',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Events',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ...events.map((event) => Card(
              child: ListTile(
                leading: const Icon(Icons.event_note),
                title: Text(event.title),
                subtitle: Text(
                  DateTime.fromMillisecondsSinceEpoch(event.startMs)
                      .toString()
                      .substring(0, 16),
                ),
                trailing: event.rrule != null
                    ? const Icon(Icons.repeat, size: 16)
                    : null,
              ),
            )),
      ],
    );
  }
}
