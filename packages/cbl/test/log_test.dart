import 'package:cbl/cbl.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  testEnvironmentSetup();

  test('get and set log level', () {
    final initialLogLevel = cbl.logLevel;

    cbl.logLevel = LogLevel.verbose;
    expect(cbl.logLevel, equals(LogLevel.verbose));

    cbl.logLevel = initialLogLevel;
  });

  test('a custom log callback should receive log messages', () async {
    cbl.logCallback = expectAsync3(
      (domain, level, message) {
        expect(message, isNotEmpty);
      },
      // Must be called at least once.
      max: -1,
      count: 1,
    );

    final db = await cbl.openDatabase(
      testDbName('LogCallback'),
      config: DatabaseConfiguration(directory: testTmpDir),
    );

    await db.close();
  });

  tearDownAll(() {
    cbl.restoreDefaultLogCallback();
  });
}
