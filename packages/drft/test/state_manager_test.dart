import 'dart:io';

import 'package:drft/drft.dart';
import 'package:test/test.dart';

void main() {
  group('StateManager', () {
    late Directory testDir;
    late StateManager stateManager;

    setUp(() {
      testDir = Directory.systemTemp.createTempSync('drft_test_');
      stateManager = StateManager(
        stateFilePath: '${testDir.path}/state.json',
      );
    });

    tearDown(() {
      testDir.deleteSync(recursive: true);
    });

    test('can save and load state', () async {
      final resource = const TestResource(id: 'test.resource');
      final state = State.fromResources([resource], stackName: 'test');

      await stateManager.save(state);
      final loaded = await stateManager.load();

      expect(loaded.stackName, equals('test'));
      expect(loaded.resources, hasLength(1));
      expect(loaded.resources['test.resource'], isNotNull);
    });

    test('returns empty state if file does not exist', () async {
      final loaded = await stateManager.load();
      expect(loaded.resources, isEmpty);
    });

    test('can lock and unlock state', () async {
      await stateManager.lock();
      // Lock file should exist
      final lockFile = File('${testDir.path}/state.json.lock');
      expect(await lockFile.exists(), isTrue);

      await stateManager.unlock();
      // Lock file should be removed
      expect(await lockFile.exists(), isFalse);
    });
  });
}

class TestResource extends Resource {
  const TestResource({
    required super.id,
    super.dependencies = const [],
  });
}
