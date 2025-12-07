import 'dart:io';

import 'package:drft/drft.dart';
import 'package:test/test.dart';

void main() {
  group('Executor', () {
    late Directory testDir;
    late StateManager stateManager;
    late Executor executor;
    late MockProvider provider;

    setUp(() {
      testDir = Directory.systemTemp.createTempSync('drft_test_');
      stateManager = StateManager(
        stateFilePath: '${testDir.path}/state.json',
      );
      provider = MockProvider();
      executor = Executor(providers: [provider]);
    });

    tearDown(() {
      testDir.deleteSync(recursive: true);
    });

    test('can execute create operation', () async {
      const resource = TestResource(id: 'test.resource', name: 'test');
      final plan = Plan(
        operations: [Operation.create(resource: resource)],
      );

      final result = await executor.execute(plan, stateManager);

      expect(result.success, isTrue);
      expect(result.operations, hasLength(1));
      expect(result.operations.first.success, isTrue);
      expect(result.operations.first.newState, isNotNull);
      expect(
        result.operations.first.newState!.resourceId,
        equals('test.resource'),
      );

      // Verify state was saved
      final savedState = await stateManager.load();
      expect(savedState.resources.containsKey('test.resource'), isTrue);
    });

    test('can execute update operation', () async {
      const resource = TestResource(id: 'test.resource', name: 'updated');
      final currentState = ResourceState(resource: resource);

      // Save initial state
      final initialState = State(
        stackName: 'test',
        resources: {'test.resource': currentState},
      );
      await stateManager.save(initialState);

      final plan = Plan(
        operations: [
          Operation.update(
            currentState: currentState,
            resource: resource,
          ),
        ],
      );

      final result = await executor.execute(plan, stateManager);

      expect(result.success, isTrue);
      expect(result.operations, hasLength(1));
      expect(result.operations.first.success, isTrue);
      expect(result.operations.first.newState, isNotNull);
    });

    test('can execute delete operation', () async {
      const resource = TestResource(id: 'test.resource', name: 'test');
      final currentState = ResourceState(resource: resource);

      // Save initial state
      final initialState = State(
        stackName: 'test',
        resources: {'test.resource': currentState},
      );
      await stateManager.save(initialState);

      final plan = Plan(
        operations: [
          Operation.delete(currentState: currentState),
        ],
      );

      final result = await executor.execute(plan, stateManager);

      expect(result.success, isTrue);
      expect(result.operations, hasLength(1));
      expect(result.operations.first.success, isTrue);

      // Verify resource was removed from state
      final savedState = await stateManager.load();
      expect(savedState.resources.containsKey('test.resource'), isFalse);
    });

    test('can execute multiple operations', () async {
      const resource1 = TestResource(id: 'resource1', name: 'test1');
      const resource2 = TestResource(id: 'resource2', name: 'test2');

      final plan = Plan(
        operations: [
          Operation.create(resource: resource1),
          Operation.create(resource: resource2),
        ],
      );

      final result = await executor.execute(plan, stateManager);

      expect(result.success, isTrue);
      expect(result.operations, hasLength(2));
      expect(result.operations.every((r) => r.success), isTrue);

      // Verify both resources were saved
      final savedState = await stateManager.load();
      expect(savedState.resources.containsKey('resource1'), isTrue);
      expect(savedState.resources.containsKey('resource2'), isTrue);
    });

    test('handles DependentResource by building it from dependencies',
        () async {
      const dependency = TestResource(id: 'dependency', name: 'dep');

      // Create DependentResource that depends on the dependency
      final dependent = DependentResource.single(
        id: 'dependent',
        dependency: dependency,
        builder: (state) {
          return const TestResource(
            id: 'dependent',
            name: 'built-from-dep',
          );
        },
      );

      // First create the dependency
      final createDepPlan = Plan(
        operations: [Operation.create(resource: dependency)],
      );
      await executor.execute(createDepPlan, stateManager);

      // Then create the dependent resource
      final plan = Plan(
        operations: [Operation.create(resource: dependent)],
      );

      final result = await executor.execute(plan, stateManager);

      expect(result.success, isTrue);
      expect(result.operations, hasLength(1));
      expect(result.operations.first.success, isTrue);

      // Verify the built resource (not the wrapper) was saved
      final savedState = await stateManager.load();
      expect(savedState.resources.containsKey('dependent'), isTrue);
      final savedResource = savedState.resources['dependent']!.resource;
      expect(savedResource, isA<TestResource>());
      expect((savedResource as TestResource).name, equals('built-from-dep'));
    });

    test('does not save state if any operation fails', () async {
      const resource1 = TestResource(id: 'resource1', name: 'test1');
      const resource2 = TestResource(id: 'resource2', name: 'test2');

      // Make provider fail for resource2
      provider.shouldFailFor = 'resource2';

      final plan = Plan(
        operations: [
          Operation.create(resource: resource1),
          Operation.create(resource: resource2),
        ],
      );

      final result = await executor.execute(plan, stateManager);

      expect(result.success, isFalse);
      expect(result.operations, hasLength(2));
      expect(result.operations[0].success, isTrue);
      expect(result.operations[1].success, isFalse);

      // Verify state was NOT saved (because one operation failed)
      final savedState = await stateManager.load();
      expect(savedState.resources, isEmpty);
    });

    test('continues executing after operation failure', () async {
      const resource1 = TestResource(id: 'resource1', name: 'test1');
      const resource2 = TestResource(id: 'resource2', name: 'test2');
      const resource3 = TestResource(id: 'resource3', name: 'test3');

      // Make provider fail for resource2
      provider.shouldFailFor = 'resource2';

      final plan = Plan(
        operations: [
          Operation.create(resource: resource1),
          Operation.create(resource: resource2),
          Operation.create(resource: resource3),
        ],
      );

      final result = await executor.execute(plan, stateManager);

      expect(result.success, isFalse);
      expect(result.operations, hasLength(3));
      expect(result.operations[0].success, isTrue);
      expect(result.operations[1].success, isFalse);
      expect(result.operations[2].success, isTrue);
    });

    test('throws error if provider not found', () async {
      // Create executor with no providers
      final emptyExecutor = Executor(providers: []);

      const resource = TestResource(id: 'test.resource', name: 'test');
      final plan = Plan(
        operations: [Operation.create(resource: resource)],
      );

      expect(
        () => emptyExecutor.execute(plan, stateManager),
        throwsA(isA<ProviderNotFoundException>()),
      );
    });

    test('generates correct summary', () async {
      const resource1 = TestResource(id: 'resource1', name: 'test1');
      const resource2 = TestResource(id: 'resource2', name: 'test2');

      final plan = Plan(
        operations: [
          Operation.create(resource: resource1),
          Operation.create(resource: resource2),
        ],
      );

      final result = await executor.execute(plan, stateManager);

      expect(result.summary, contains('Successful: 2'));
      expect(result.summary, contains('Failed: 0'));
      expect(result.summary, contains('Total: 2'));
    });

    test('locks and unlocks state manager', () async {
      const resource = TestResource(id: 'test.resource', name: 'test');
      final plan = Plan(
        operations: [Operation.create(resource: resource)],
      );

      await executor.execute(plan, stateManager);

      // Lock file should not exist after execution
      final lockFile = File('${testDir.path}/state.json.lock');
      expect(await lockFile.exists(), isFalse);
    });

    test('preserves stack name from desired state', () async {
      const resource = TestResource(id: 'test.resource', name: 'test');
      final plan = Plan(
        operations: [Operation.create(resource: resource)],
      );

      final desiredState = State(
        stackName: 'my-stack',
        resources: {},
      );

      await executor.execute(plan, stateManager, desiredState: desiredState);

      final savedState = await stateManager.load();
      expect(savedState.stackName, equals('my-stack'));
    });

    test('reads ReadOnlyResource that exists externally', () async {
      const readOnlyResource = TestReadOnlyResource(
        id: 'readonly.resource',
        name: 'readonly',
      );

      // Create a plan with no operations (ReadOnlyResource won't be in plan)
      final plan = Plan(operations: []);

      // But include it in desired state
      final desiredState = State(
        stackName: 'test',
        resources: {
          'readonly.resource': ResourceState(resource: readOnlyResource),
        },
      );

      // Mock provider should handle readResource for ReadOnlyResource
      provider.readOnlyResourceState =
          ResourceState(resource: readOnlyResource);

      await executor.execute(plan, stateManager, desiredState: desiredState);

      // ReadOnlyResource state should be saved
      final savedState = await stateManager.load();
      expect(savedState.resources.containsKey('readonly.resource'), isTrue);
    });

    test('throws error if ReadOnlyResource does not exist externally',
        () async {
      const readOnlyResource = TestReadOnlyResource(
        id: 'readonly.resource',
        name: 'readonly',
      );

      final plan = Plan(operations: []);

      final desiredState = State(
        stackName: 'test',
        resources: {
          'readonly.resource': ResourceState(resource: readOnlyResource),
        },
      );

      // Provider will throw ResourceNotFoundException
      provider.shouldThrowNotFoundFor = 'readonly.resource';

      expect(
        () => executor.execute(plan, stateManager, desiredState: desiredState),
        throwsA(
          isA<DrftException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Read-only resource'),
              contains('not found'),
            ),
          ),
        ),
      );
    });
  });
}

/// Test resource for testing
class TestResource extends Resource {
  final String name;

  const TestResource({
    required super.id,
    required this.name,
    super.dependencies = const [],
  });
}

/// Test read-only resource for testing ReadOnlyResource behavior
class TestReadOnlyResource extends ReadOnlyResource {
  final String name;

  const TestReadOnlyResource({
    required super.id,
    required this.name,
    super.dependencies = const [],
  });
}

/// Mock provider that can be configured to fail for specific resources
class MockProvider extends Provider<Resource> {
  String? shouldFailFor;
  String? shouldThrowNotFoundFor;
  ResourceState? readOnlyResourceState;

  MockProvider({
    this.shouldFailFor,
    this.shouldThrowNotFoundFor,
    this.readOnlyResourceState,
  }) : super(
          name: 'mock',
          version: '1.0.0',
        );

  @override
  Future<void> configure(Map<String, dynamic> config) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  bool canHandle(Resource resource) => true;

  @override
  Future<ResourceState> createResource(Resource resource) async {
    if (shouldFailFor == resource.id) {
      throw Exception('Simulated failure for ${resource.id}');
    }
    return ResourceState(resource: resource);
  }

  @override
  Future<ResourceState> readResource(Resource resource) async {
    if (shouldThrowNotFoundFor == resource.id) {
      throw ResourceNotFoundException(resource.id);
    }
    if (resource is ReadOnlyResource && readOnlyResourceState != null) {
      return readOnlyResourceState!;
    }
    return ResourceState(resource: resource);
  }

  @override
  Future<ResourceState> updateResource(
    ResourceState current,
    Resource desired,
  ) async {
    if (shouldFailFor == desired.id) {
      throw Exception('Simulated failure for ${desired.id}');
    }
    return ResourceState(resource: desired);
  }

  @override
  Future<void> deleteResource(ResourceState state) async {
    if (shouldFailFor == state.resourceId) {
      throw Exception('Simulated failure for ${state.resourceId}');
    }
  }
}
