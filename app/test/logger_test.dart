import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/logging/logger.dart';

void main() {
  test('writes ndjson', () async {
    final logger = Logger();
    await logger.init();
    logger.debugEvt('unit.test', {'k': 'v'});
    await logger.flush();
    final f = File(logger.logFilePath);
    expect(await f.exists(), true);
    final text = await f.readAsString();
    expect(text.contains('unit.test'), true);
  });
}
