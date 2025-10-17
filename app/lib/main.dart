import 'package:flutter/material.dart';
import 'logging/logger.dart';

Future<void> main() async {
  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger with configuration
  await Logger.initialize(
    config: const LoggerConfig(
      level: LogLevel.info, // Only INFO, WARN, and ERROR (no TRACE or DEBUG)
      console: true,
      structuredLogging: false, // Use plain text for easier reading
      keepDays: 7,
    ),
  );

  final logger = Logger.instance;
  logger.info(
    'Application starting',
    tag: 'main',
    metadata: {'version': '1.0.0'},
  );

  try {
    runApp(const MyApp());
    logger.info('MyApp widget created successfully', tag: 'main');
  } catch (e, stack) {
    logger.error(
      'Failed to start application',
      tag: 'main',
      error: e,
      stackTrace: stack,
    );
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = Logger.instance;
    logger.debug('Building MyApp widget', tag: 'MyApp');

    return MaterialApp(
      title: 'Calendar MVP',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const HomePage(),
      builder: (context, child) {
        logger.trace('MaterialApp builder called', tag: 'MyApp');
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int taps = 0;
  final logger = Logger.instance;

  @override
  void initState() {
    super.initState();
    logger.info(
      'HomePage initialized',
      tag: 'HomePage',
      metadata: {'initialTaps': taps},
    );
  }

  @override
  void dispose() {
    logger.info(
      'HomePage disposing',
      tag: 'HomePage',
      metadata: {'finalTaps': taps},
    );
    super.dispose();
  }

  void _handleTap() {
    logger.trace(
      'Tap button pressed',
      tag: 'HomePage',
      metadata: {'currentTaps': taps},
    );

    setState(() {
      taps++;
    });

    logger.debug(
      'Tap count updated',
      tag: 'HomePage',
      metadata: {'newTaps': taps},
    );

    // Demonstrate different log levels based on tap count
    if (taps == 5) {
      logger.info('User reached 5 taps milestone!', tag: 'HomePage');
    } else if (taps == 10) {
      logger.warn(
        'User has tapped 10 times',
        tag: 'HomePage',
        error: 'Possible excessive tapping',
      );
    } else if (taps > 15) {
      logger.error(
        'Tap count exceeds expected range',
        tag: 'HomePage',
        metadata: {'taps': taps, 'threshold': 15},
        error: Exception('Tap overflow detected'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    logger.trace(
      'Building HomePage',
      tag: 'HomePage',
      metadata: {'taps': taps},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Shell'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              logger.info('Reset button pressed', tag: 'HomePage');
              setState(() {
                taps = 0;
              });
              logger.debug('Tap count reset to 0', tag: 'HomePage');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Hello! taps=$taps',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              'Check console for logging output',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleTap,
        child: const Icon(Icons.add),
      ),
    );
  }
}
