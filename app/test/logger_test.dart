import 'package:flutter_test/flutter_test.dart';
import 'package:app/logging/logger.dart';

void main() {
  test('logger initializes and logs messages', () async {
    // Initialize logger
    final logger = await Logger.initialize();

    // Log various levels
    logger.debug('Test debug message', tag: 'Test');
    logger.info('Test info message', tag: 'Test', metadata: {'key': 'value'});
    logger.warn('Test warning', tag: 'Test');

    // Logger should be initialized
    expect(Logger.instance, isNotNull);

    // Shutdown
    await logger.shutdown();
  });
}
