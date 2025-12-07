import 'dart:io';

import 'package:drft/drft.dart';
import 'package:test/test.dart';

void main() {
  group('DrftStack', () {
    late Directory testDir;
    late StateManager stateManager;
    late MockProvider provider;

    setUp(() {
      testDir = Directory.systemTemp.createTempSync('drft_test_');
      stateManager = StateManager(
        stateFilePath: '${testDir.path}/state.json',
      );
      provider = MockProvider();
    });

    tearDown(() {
      testDir.deleteSync(recursive: true);
    });

    group('plan', () {
      test('creates plan with create operation for new resource', () async {
        const resource = TestResource(id: 'test.resource', name: 'test');
        final stackWithResource = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [resource],
          stateManager: stateManager,
        );

        final plan = await stackWithResource.plan();

        expect(plan.operations, hasLength(1));
        expect(plan.operations.first.type, equals(OperationType.create));
        expect(plan.operations.first.resource?.id, equals('test.resource'));
      });

      test('creates plan with update operation for changed resource', () async {
        const originalResource = TestResource(id: 'test.resource', name: 'old');
        const updatedResource = TestResource(id: 'test.resource', name: 'new');

        // Save initial state
        final initialState = State(
          stackName: 'test-stack',
          resources: {
            'test.resource': ResourceState(resource: originalResource),
          },
        );
        await stateManager.save(initialState);

        final stackWithResource = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [updatedResource],
          stateManager: stateManager,
        );

        final plan = await stackWithResource.plan();

        expect(plan.operations, hasLength(1));
        expect(plan.operations.first.type, equals(OperationType.update));
        expect(plan.operations.first.resource?.id, equals('test.resource'));
      });

      test('creates plan with delete operation for removed resource', () async {
        const resource = TestResource(id: 'test.resource', name: 'test');

        // Save initial state
        final initialState = State(
          stackName: 'test-stack',
          resources: {
            'test.resource': ResourceState(resource: resource),
          },
        );
        await stateManager.save(initialState);

        // Stack with no resources (empty desired state)
        final emptyStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: const [],
          stateManager: stateManager,
        );

        final plan = await emptyStack.plan();

        expect(plan.operations, hasLength(1));
        expect(plan.operations.first.type, equals(OperationType.delete));
        expect(
          plan.operations.first.currentState?.resourceId,
          equals('test.resource'),
        );
      });

      test('creates plan with no operations when resources match', () async {
        const resource = TestResource(id: 'test.resource', name: 'test');

        // Save initial state
        final initialState = State(
          stackName: 'test-stack',
          resources: {
            'test.resource': ResourceState(resource: resource),
          },
        );
        await stateManager.save(initialState);

        final stackWithResource = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [resource],
          stateManager: stateManager,
        );

        final plan = await stackWithResource.plan();

        expect(plan.operations, isEmpty);
      });

      test('supports verbose info in plan', () async {
        const resource = TestResource(id: 'test.resource', name: 'test');
        final stackWithResource = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [resource],
          stateManager: stateManager,
        );

        final plan = await stackWithResource.plan(includeVerboseInfo: true);

        expect(plan.operations, hasLength(1));
        expect(plan.verboseInfo, isNotNull);
      });
    });

    group('apply', () {
      test('applies plan to create resource', () async {
        const resource = TestResource(id: 'test.resource', name: 'test');
        final stackWithResource = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [resource],
          stateManager: stateManager,
        );

        final plan = await stackWithResource.plan();
        final result = await stackWithResource.apply(plan);

        expect(result.success, isTrue);
        expect(result.operations, hasLength(1));
        expect(result.operations.first.success, isTrue);

        // Verify state was saved
        final savedState = await stateManager.load();
        expect(savedState.resources.containsKey('test.resource'), isTrue);
        expect(savedState.stackName, equals('test-stack'));
      });

      test('applies plan to update resource', () async {
        const originalResource = TestResource(id: 'test.resource', name: 'old');
        const updatedResource = TestResource(id: 'test.resource', name: 'new');

        // Save initial state
        final initialState = State(
          stackName: 'test-stack',
          resources: {
            'test.resource': ResourceState(resource: originalResource),
          },
        );
        await stateManager.save(initialState);

        final stackWithResource = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [updatedResource],
          stateManager: stateManager,
        );

        final plan = await stackWithResource.plan();
        final result = await stackWithResource.apply(plan);

        expect(result.success, isTrue);
        expect(result.operations, hasLength(1));
        expect(result.operations.first.success, isTrue);

        // Verify state was updated
        final savedState = await stateManager.load();
        expect(savedState.resources.containsKey('test.resource'), isTrue);
      });

      test('applies plan to delete resource', () async {
        const resource = TestResource(id: 'test.resource', name: 'test');

        // Save initial state
        final initialState = State(
          stackName: 'test-stack',
          resources: {
            'test.resource': ResourceState(resource: resource),
          },
        );
        await stateManager.save(initialState);

        // Stack with no resources
        final emptyStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: const [],
          stateManager: stateManager,
        );

        final plan = await emptyStack.plan();
        final result = await emptyStack.apply(plan);

        expect(result.success, isTrue);
        expect(result.operations, hasLength(1));
        expect(result.operations.first.success, isTrue);

        // Verify resource was removed from state
        final savedState = await stateManager.load();
        expect(savedState.resources.containsKey('test.resource'), isFalse);
      });
    });

    group('refresh', () {
      test('refreshes state from provider', () async {
        const resource = TestResource(id: 'test.resource', name: 'test');

        // First create the resource so it exists in the provider
        final createStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [resource],
          stateManager: stateManager,
        );
        final createPlan = await createStack.plan();
        await createStack.apply(createPlan);

        // Now refresh it
        final refreshedState = await createStack.refresh();

        expect(refreshedState.stackName, equals('test-stack'));
        expect(refreshedState.resources.containsKey('test.resource'), isTrue);
        expect(refreshedState.resources['test.resource']!.resourceId,
            equals('test.resource'));

        // Verify state was saved
        final savedState = await stateManager.load();
        expect(savedState.resources.containsKey('test.resource'), isTrue);
      });

      test('throws exception when no provider found for resource', () async {
        const resource = TestResource(id: 'test.resource', name: 'test');

        // Save initial state
        final initialState = State(
          stackName: 'test-stack',
          resources: {
            'test.resource': ResourceState(resource: resource),
          },
        );
        await stateManager.save(initialState);

        // Stack with no providers (provider can't handle the resource)
        final stackWithoutProvider = DrftStack(
          name: 'test-stack',
          providers: [], // No providers
          resources: [resource],
          stateManager: stateManager,
        );

        expect(
          () => stackWithoutProvider.refresh(),
          throwsA(isA<DrftException>()),
        );
      });

      test('refreshes multiple resources', () async {
        const resource1 = TestResource(id: 'resource1', name: 'test1');
        const resource2 = TestResource(id: 'resource2', name: 'test2');

        // First create the resources so they exist in the provider
        final createStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [resource1, resource2],
          stateManager: stateManager,
        );
        final createPlan = await createStack.plan();
        await createStack.apply(createPlan);

        // Now refresh them
        final refreshedState = await createStack.refresh();

        expect(refreshedState.resources, hasLength(2));
        expect(refreshedState.resources.containsKey('resource1'), isTrue);
        expect(refreshedState.resources.containsKey('resource2'), isTrue);
      });

      test('calls readResource on provider for each resource', () async {
        const resource1 = TestResource(id: 'resource1', name: 'test1');
        const resource2 = TestResource(id: 'resource2', name: 'test2');

        // Create a tracking provider that records readResource calls
        final trackingProvider = TrackingProvider();

        // First create the resources so they exist in the provider
        final createStack = DrftStack(
          name: 'test-stack',
          providers: [trackingProvider],
          resources: [resource1, resource2],
          stateManager: stateManager,
        );
        final createPlan = await createStack.plan();
        await createStack.apply(createPlan);

        // Clear the call history
        trackingProvider.clearReadCalls();

        // Now refresh them
        await createStack.refresh();

        // Verify readResource was called for each resource
        expect(trackingProvider.readResourceCalls, hasLength(2));
        expect(
          trackingProvider.readResourceCalls,
          containsAll([
            'resource1',
            'resource2',
          ]),
        );
      });

      test('skips resources that are not found in infrastructure', () async {
        const existingResource = TestResource(id: 'existing', name: 'test');
        const missingResource = TestResource(id: 'missing', name: 'test');

        // Create only one resource so the other doesn't exist
        final createStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [existingResource],
          stateManager: stateManager,
        );
        final createPlan = await createStack.plan();
        await createStack.apply(createPlan);

        // Now refresh with both resources - one exists, one doesn't
        final refreshStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [existingResource, missingResource],
          stateManager: stateManager,
        );

        final refreshedState = await refreshStack.refresh();

        // Only the existing resource should be in the refreshed state
        expect(refreshedState.resources, hasLength(1));
        expect(refreshedState.resources.containsKey('existing'), isTrue);
        expect(refreshedState.resources.containsKey('missing'), isFalse);
      });

      test('reads resources from stack definition, not from state', () async {
        const stackResource1 =
            TestResource(id: 'stack.resource1', name: 'stack1');
        const stackResource2 =
            TestResource(id: 'stack.resource2', name: 'stack2');
        const stateResource = TestResource(id: 'state.resource', name: 'state');

        // Create resources that will be in the stack
        final createStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [stackResource1, stackResource2],
          stateManager: stateManager,
        );
        final createPlan = await createStack.plan();
        await createStack.apply(createPlan);

        // Save a state with a different resource that's not in the stack
        final stateWithExtraResource = State(
          stackName: 'test-stack',
          resources: {
            'stack.resource1': ResourceState(resource: stackResource1),
            'stack.resource2': ResourceState(resource: stackResource2),
            'state.resource': ResourceState(resource: stateResource),
          },
        );
        await stateManager.save(stateWithExtraResource);

        // Refresh should only read resources from the stack definition
        final refreshStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [stackResource1, stackResource2], // Only these two
          stateManager: stateManager,
        );

        final refreshedState = await refreshStack.refresh();

        // Should only have the two resources from the stack, not the one from state
        expect(refreshedState.resources, hasLength(2));
        expect(refreshedState.resources.containsKey('stack.resource1'), isTrue);
        expect(refreshedState.resources.containsKey('stack.resource2'), isTrue);
        expect(refreshedState.resources.containsKey('state.resource'), isFalse);
      });

      test('creates completely new state, not based on existing state',
          () async {
        const resource = TestResource(id: 'test.resource', name: 'test');

        // Create and save a resource
        final createStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [resource],
          stateManager: stateManager,
        );
        final createPlan = await createStack.plan();
        await createStack.apply(createPlan);

        // Verify initial state exists
        final initialState = await stateManager.load();
        expect(initialState.resources.containsKey('test.resource'), isTrue);

        // Refresh should create a new state with stack name
        final refreshedState = await createStack.refresh();

        // Should be a new state with correct stack name
        expect(refreshedState.stackName, equals('test-stack'));
        expect(refreshedState.resources.containsKey('test.resource'), isTrue);
      });

      test(
          'throws exception when no provider found, even without existing state',
          () async {
        const resource = TestResource(id: 'test.resource', name: 'test');

        // Stack with no providers - should throw immediately
        final stackWithoutProvider = DrftStack(
          name: 'test-stack',
          providers: [], // No providers
          resources: [resource],
          stateManager: stateManager,
        );

        expect(
          () => stackWithoutProvider.refresh(),
          throwsA(
            isA<DrftException>().having(
              (e) => e.toString(),
              'message',
              contains('No provider found for resource'),
            ),
          ),
        );
      });

      test('propagates exceptions other than ResourceNotFoundException',
          () async {
        const resource = TestResource(id: 'test.resource', name: 'test');

        // Create a provider that throws a different exception
        final failingProvider = ExceptionThrowingProvider();

        final stack = DrftStack(
          name: 'test-stack',
          providers: [failingProvider],
          resources: [resource],
          stateManager: stateManager,
        );

        // Should propagate the exception, not catch it
        expect(
          () => stack.refresh(),
          throwsA(isA<DrftException>()),
        );
      });

      test('refreshes all resources from stack even if state is empty',
          () async {
        const resource1 = TestResource(id: 'resource1', name: 'test1');
        const resource2 = TestResource(id: 'resource2', name: 'test2');

        // Create resources so they exist in the provider
        final createStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [resource1, resource2],
          stateManager: stateManager,
        );
        final createPlan = await createStack.plan();
        await createStack.apply(createPlan);

        // Clear the state file (simulate empty state)
        final emptyState = State.empty(stackName: 'test-stack');
        await stateManager.save(emptyState);

        // Refresh should still read all resources from the stack definition
        final refreshStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [resource1, resource2],
          stateManager: stateManager,
        );

        final refreshedState = await refreshStack.refresh();

        // Should have both resources even though state was empty
        expect(refreshedState.resources, hasLength(2));
        expect(refreshedState.resources.containsKey('resource1'), isTrue);
        expect(refreshedState.resources.containsKey('resource2'), isTrue);
      });
    });

    group('destroy', () {
      test('destroys all resources in stack', () async {
        const resource1 = TestResource(id: 'resource1', name: 'test1');
        const resource2 = TestResource(id: 'resource2', name: 'test2');

        // Save initial state
        final initialState = State(
          stackName: 'test-stack',
          resources: {
            'resource1': ResourceState(resource: resource1),
            'resource2': ResourceState(resource: resource2),
          },
        );
        await stateManager.save(initialState);

        final stackWithResources = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [resource1, resource2],
          stateManager: stateManager,
        );

        final result = await stackWithResources.destroy();

        expect(result.success, isTrue);
        expect(result.operations, hasLength(2));
        expect(result.operations.every((r) => r.success), isTrue);

        // Verify all resources were removed from state
        final savedState = await stateManager.load();
        expect(savedState.resources, isEmpty);
      });

      test('returns success when no resources to destroy', () async {
        // Empty state
        final emptyState = State(
          stackName: 'test-stack',
          resources: {},
        );
        await stateManager.save(emptyState);

        final emptyStack = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: const [],
          stateManager: stateManager,
        );

        final result = await emptyStack.destroy();

        expect(result.success, isTrue);
        expect(result.operations, isEmpty);
      });

      test('destroys resources in reverse dependency order', () async {
        const dependency = TestResource(id: 'dependency', name: 'dep');
        final dependent = TestResource(
          id: 'dependent',
          name: 'dep',
          dependencies: [dependency],
        );

        // Save initial state
        final initialState = State(
          stackName: 'test-stack',
          resources: {
            'dependency': ResourceState(resource: dependency),
            'dependent': ResourceState(resource: dependent),
          },
        );
        await stateManager.save(initialState);

        final stackWithResources = DrftStack(
          name: 'test-stack',
          providers: [provider],
          resources: [dependency, dependent],
          stateManager: stateManager,
        );

        final result = await stackWithResources.destroy();

        expect(result.success, isTrue);
        expect(result.operations, hasLength(2));
        // Dependent should be deleted before dependency
        expect(result.operations.first.operation.type,
            equals(OperationType.delete));
        expect(result.operations.first.operation.currentState?.resourceId,
            equals('dependent'));
        expect(result.operations.last.operation.currentState?.resourceId,
            equals('dependency'));
      });
    });
  });
}

/// Test resource for stack tests
class TestResource extends Resource {
  final String name;

  const TestResource({
    required String id,
    required this.name,
    List<Resource> dependencies = const [],
  }) : super(
          id: id,
          dependencies: dependencies,
        );
}

/// Provider that tracks readResource calls for testing
class TrackingProvider extends MockProvider {
  final List<String> _readResourceCalls = [];

  List<String> get readResourceCalls => List.unmodifiable(_readResourceCalls);

  void clearReadCalls() {
    _readResourceCalls.clear();
  }

  @override
  Future<ResourceState> readResource(Resource resource) async {
    _readResourceCalls.add(resource.id);
    return await super.readResource(resource);
  }
}

/// Provider that throws DrftException (not ResourceNotFoundException) for testing
class ExceptionThrowingProvider extends Provider<Resource> {
  ExceptionThrowingProvider()
      : super(
          name: 'exception-throwing',
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
    throw DrftException('Create not supported in test provider');
  }

  @override
  Future<ResourceState> readResource(Resource resource) async {
    // Throw DrftException (not ResourceNotFoundException) to test exception propagation
    throw DrftException('Test exception from provider');
  }

  @override
  Future<ResourceState> updateResource(
    ResourceState current,
    Resource desired,
  ) async {
    throw DrftException('Update not supported in test provider');
  }

  @override
  Future<void> deleteResource(ResourceState state) async {
    throw DrftException('Delete not supported in test provider');
  }
}
