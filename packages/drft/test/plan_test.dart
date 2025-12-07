import 'package:drft/drft.dart';
import 'package:drft/src/core/resource_serialization.dart';
import 'package:test/test.dart';

void main() {
  group('Planner', () {
    late Planner planner;

    setUp(() {
      planner = Planner();
    });

    test('creates plan with create operation for new resource', () {
      const resource = TestResource(id: 'test.resource', name: 'test');
      final desired = State.fromResources([resource], stackName: 'test');
      final actual = State.empty(stackName: 'test');

      final plan = planner.createPlan(desired: desired, actual: actual);

      expect(plan.operations, hasLength(1));
      expect(plan.operations.first.type, equals(OperationType.create));
      expect(plan.operations.first.resource?.id, equals('test.resource'));
    });

    test('creates plan with update operation for changed resource', () {
      const originalResource = TestResource(id: 'test.resource', name: 'old');
      const updatedResource = TestResource(id: 'test.resource', name: 'new');

      final desired = State.fromResources([updatedResource], stackName: 'test');
      final actual = State(
        version: '1.0',
        stackName: 'test',
        resources: {
          'test.resource': ResourceState(resource: originalResource),
        },
      );

      final plan = planner.createPlan(desired: desired, actual: actual);

      expect(plan.operations, hasLength(1));
      expect(plan.operations.first.type, equals(OperationType.update));
      expect(plan.operations.first.resource?.id, equals('test.resource'));
    });

    test('creates plan with delete operation for removed resource', () {
      const resource = TestResource(id: 'test.resource', name: 'test');

      final desired = State.empty(stackName: 'test');
      final actual = State(
        version: '1.0',
        stackName: 'test',
        resources: {
          'test.resource': ResourceState(resource: resource),
        },
      );

      final plan = planner.createPlan(desired: desired, actual: actual);

      expect(plan.operations, hasLength(1));
      expect(plan.operations.first.type, equals(OperationType.delete));
      expect(
        plan.operations.first.currentState?.resourceId,
        equals('test.resource'),
      );
    });

    test('creates plan with no operations when resources match', () {
      const resource = TestResource(id: 'test.resource', name: 'test');

      final desired = State.fromResources([resource], stackName: 'test');
      final actual = State(
        version: '1.0',
        stackName: 'test',
        resources: {
          'test.resource': ResourceState(resource: resource),
        },
      );

      final plan = planner.createPlan(desired: desired, actual: actual);

      expect(plan.operations, isEmpty);
    });

    test('creates plan with multiple operations', () {
      const resource1 = TestResource(id: 'resource1', name: 'test1');
      const resource2 = TestResource(id: 'resource2', name: 'test2');
      const resource3 = TestResource(id: 'resource3', name: 'test3');

      final desired =
          State.fromResources([resource1, resource2], stackName: 'test');
      final actual = State(
        version: '1.0',
        stackName: 'test',
        resources: {
          'resource3': ResourceState(resource: resource3),
        },
      );

      final plan = planner.createPlan(desired: desired, actual: actual);

      expect(plan.operations, hasLength(3));
      expect(
        plan.operations.where((op) => op.type == OperationType.create).length,
        equals(2),
      );
      expect(
        plan.operations.where((op) => op.type == OperationType.delete).length,
        equals(1),
      );
    });

    test('orders create operations by dependencies', () {
      const resource1 = TestResource(id: 'resource1', name: 'test1');
      final resource2 = const TestResource(
        id: 'resource2',
        name: 'test2',
        dependencies: [resource1],
      );

      final desired =
          State.fromResources([resource1, resource2], stackName: 'test');
      final actual = State.empty(stackName: 'test');

      final plan = planner.createPlan(desired: desired, actual: actual);

      expect(plan.operations, hasLength(2));
      expect(plan.operations[0].resource?.id, equals('resource1'));
      expect(plan.operations[1].resource?.id, equals('resource2'));
    });

    test('orders delete operations by reverse dependencies', () {
      const resource1 = TestResource(id: 'resource1', name: 'test1');
      final resource2 = const TestResource(
        id: 'resource2',
        name: 'test2',
        dependencies: [resource1],
      );

      final desired = State.empty(stackName: 'test');
      final actual = State(
        version: '1.0',
        stackName: 'test',
        resources: {
          'resource1': ResourceState(resource: resource1),
          'resource2': ResourceState(resource: resource2),
        },
      );

      final plan = planner.createPlan(desired: desired, actual: actual);

      expect(plan.operations, hasLength(2));
      expect(plan.operations[0].currentState?.resourceId, equals('resource2'));
      expect(plan.operations[1].currentState?.resourceId, equals('resource1'));
    });

    test('handles DependentResource when dependencies exist', () {
      const dependency = TestResource(id: 'dependency', name: 'dep');
      final dependencyState = ResourceState(resource: dependency);

      final dependent = DependentResource.single(
        id: 'dependent',
        dependency: dependency,
        builder: (state) {
          return const TestResource(
            id: 'dependent',
            name: 'built',
          );
        },
      );

      // Both dependency and dependent must be in desired state
      final desired =
          State.fromResources([dependency, dependent], stackName: 'test');
      final actual = State(
        version: '1.0',
        stackName: 'test',
        resources: {
          'dependency': dependencyState,
        },
      );

      final plan = planner.createPlan(desired: desired, actual: actual);

      // Should create the dependent resource (dependency already exists)
      expect(plan.operations.length, greaterThanOrEqualTo(1));
      // The dependent resource should be created
      expect(
        plan.operations.any(
          (op) =>
              op.type == OperationType.create && op.resource?.id == 'dependent',
        ),
        isTrue,
      );
    });

    test('throws error for DependentResource when dependencies missing', () {
      const dependency = TestResource(id: 'dependency', name: 'dep');

      final dependent = DependentResource.single(
        id: 'dependent',
        dependency: dependency,
        builder: (state) {
          return const TestResource(
            id: 'dependent',
            name: 'built',
          );
        },
      );

      // Create a state with the dependent resource already existing
      final currentDependent = const TestResource(id: 'dependent', name: 'old');
      final currentState = ResourceState(resource: currentDependent);

      final desired = State.fromResources([dependent], stackName: 'test');
      final actual = State(
        version: '1.0',
        stackName: 'test',
        resources: {
          'dependent': currentState,
          // Note: dependency is NOT in actual state
        },
      );

      // Should throw error since dependencies don't exist
      expect(
        () => planner.createPlan(desired: desired, actual: actual),
        throwsA(
          isA<DrftException>().having(
            (e) => e.message,
            'message',
            contains('depends on missing resources'),
          ),
        ),
      );
    });

    test('includes verbose info when requested', () {
      const originalResource = TestResource(id: 'test.resource', name: 'old');
      const updatedResource = TestResource(id: 'test.resource', name: 'new');

      final desired = State.fromResources([updatedResource], stackName: 'test');
      final actual = State(
        version: '1.0',
        stackName: 'test',
        resources: {
          'test.resource': ResourceState(resource: originalResource),
        },
      );

      final plan = planner.createPlan(
        desired: desired,
        actual: actual,
        includeVerboseInfo: true,
      );

      expect(plan.verboseInfo.differences.containsKey('test.resource'), isTrue);
      expect(plan.verboseInfo.differences['test.resource'], isNotEmpty);
      expect(
        plan.verboseInfo.differences['test.resource']!.first.field,
        equals('name'),
      );
    });

    test('includes unchanged resources in verbose info', () {
      const resource = TestResource(id: 'test.resource', name: 'test');

      final desired = State.fromResources([resource], stackName: 'test');
      final actual = State(
        version: '1.0',
        stackName: 'test',
        resources: {
          'test.resource': ResourceState(resource: resource),
        },
      );

      final plan = planner.createPlan(
        desired: desired,
        actual: actual,
        includeVerboseInfo: true,
      );

      expect(plan.verboseInfo.unchanged, contains('test.resource'));
    });

    test('throws error when dependency is missing', () {
      const dependency = TestResource(id: 'dependency', name: 'dep');
      final resource = const TestResource(
        id: 'resource',
        name: 'test',
        dependencies: [dependency],
      );

      // Only add resource, not its dependency
      final desired = State.fromResources([resource], stackName: 'test');
      final actual = State.empty(stackName: 'test');

      expect(
        () => planner.createPlan(desired: desired, actual: actual),
        throwsA(
          isA<DrftException>().having(
            (e) => e.message,
            'message',
            contains('Resource "resource" depends on missing resources'),
          ),
        ),
      );
    });

    test('handles complex dependency chain', () {
      const resource1 = TestResource(id: 'resource1', name: 'test1');
      final resource2 = const TestResource(
        id: 'resource2',
        name: 'test2',
        dependencies: [resource1],
      );
      final resource3 = TestResource(
        id: 'resource3',
        name: 'test3',
        dependencies: [resource2],
      );

      final desired = State.fromResources(
        [resource1, resource2, resource3],
        stackName: 'test',
      );
      final actual = State.empty(stackName: 'test');

      final plan = planner.createPlan(desired: desired, actual: actual);

      expect(plan.operations, hasLength(3));
      // Verify order: resource1, then resource2, then resource3
      expect(plan.operations[0].resource?.id, equals('resource1'));
      expect(plan.operations[1].resource?.id, equals('resource2'));
      expect(plan.operations[2].resource?.id, equals('resource3'));
    });

    test('handles resources with no dependencies', () {
      const resource1 = TestResource(id: 'resource1', name: 'test1');
      const resource2 = TestResource(id: 'resource2', name: 'test2');

      final desired =
          State.fromResources([resource1, resource2], stackName: 'test');
      final actual = State.empty(stackName: 'test');

      final plan = planner.createPlan(desired: desired, actual: actual);

      expect(plan.operations, hasLength(2));
      // Order doesn't matter for independent resources
      expect(
        plan.operations.map((op) => op.resource?.id).toSet(),
        equals(const {'resource1', 'resource2'}),
      );
    });

    test('detects changes in nested properties', () {
      const originalResource = TestResource(
        id: 'test.resource',
        name: 'test',
        tags: ['tag1'],
      );
      const updatedResource = TestResource(
        id: 'test.resource',
        name: 'test',
        tags: ['tag1', 'tag2'],
      );

      final desired = State.fromResources([updatedResource], stackName: 'test');
      final actual = State(
        version: '1.0',
        stackName: 'test',
        resources: {
          'test.resource': ResourceState(resource: originalResource),
        },
      );

      final plan = planner.createPlan(desired: desired, actual: actual);

      expect(plan.operations, hasLength(1));
      expect(plan.operations.first.type, equals(OperationType.update));
    });
  });

  group('Plan Properties Comparison', () {
    test('plan correctly detects changes when properties differ', () async {
      // Create a simple test resource
      final resource1 = const TestResourceWithValue(
        id: 'test1',
        name: 'Test',
        value: 42,
      );

      final resource2 = const TestResourceWithValue(
        id: 'test1',
        name: 'Test',
        value: 43, // Different value
      );

      // Create a stack with the first resource
      final stack = DrftStack(
        name: 'test-stack',
        providers: [MockProvider()],
        resources: [resource1],
      );

      // Apply to create initial state
      final plan1 = await stack.plan();
      await stack.apply(plan1);

      // Update the resource
      final updatedStack = DrftStack(
        name: 'test-stack',
        providers: [MockProvider()],
        resources: [resource2],
      );

      // Create a new plan - should detect changes
      final plan2 = await updatedStack.plan();

      // Should have an update operation
      expect(
        plan2.operations.any((op) => op.type == OperationType.update),
        isTrue,
      );
    });

    test('ResourceSerialization.toJson returns properties at top level', () {
      final resource = const TestResourceWithValue(
        id: 'test1',
        name: 'Test',
        value: 42,
      );

      final json = ResourceSerialization.toJson(resource);

      // Properties should be at top level, not under 'properties' key
      expect(json.containsKey('properties'), isFalse);
      expect(json['name'], equals('Test'));
      expect(json['value'], equals(42));
      expect(json['id'], equals('test1'));
      expect(json.containsKey('.type'), isTrue);
      expect(json.containsKey('dependencies'), isTrue);
    });
  });
}

/// Test resource for testing
class TestResource extends Resource {
  final String name;
  final List<String> tags;

  const TestResource({
    required super.id,
    required this.name,
    this.tags = const [],
    super.dependencies = const [],
  });
}

/// Test resource with value field for property comparison tests
class TestResourceWithValue extends Resource {
  final String name;
  final int value;

  const TestResourceWithValue({
    required super.id,
    required this.name,
    required this.value,
    super.dependencies,
  });
}
