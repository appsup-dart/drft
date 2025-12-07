import 'package:drft/drft.dart';
import 'package:drft/src/core/resource_state_serialization.dart';
import 'package:test/test.dart';

void main() {
  group('ResourceState Serialization', () {
    test('can serialize basic ResourceState', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'hello',
        optionalValue: 42,
      );
      final state = TestResourceState(
        resource: resource,
        testValue: 'hello',
        optionalValue: 42,
      );

      final json = ResourceStateSerialization.toJson(state);

      // Metadata fields
      expect(json['.type'], contains('TestResourceState'));
      expect(json['resource'], isA<Map>());

      // Properties at top level
      expect(json['testValue'], equals('hello'));
      expect(json['optionalValue'], equals(42));

      // Resource should be serialized
      final resourceJson = json['resource'] as Map<String, dynamic>;
      expect(resourceJson['.type'], contains('TestResource'));
      expect(resourceJson['id'], equals('test.resource'));
    });

    test('can serialize ResourceState with null values', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'hello',
      );
      final state = TestResourceState(
        resource: resource,
        testValue: 'hello',
        optionalValue: null,
      );

      final json = ResourceStateSerialization.toJson(state);

      expect(json['testValue'], equals('hello'));
      expect(json['optionalValue'], isNull);
    });

    test('serialization includes all public fields', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'test',
        optionalValue: 123,
      );
      final state = TestResourceState(
        resource: resource,
        testValue: 'test',
        optionalValue: 123,
      );

      final json = ResourceStateSerialization.toJson(state);

      // Check for metadata and properties
      expect(
        json.keys,
        containsAll(['.type', 'resource', 'testValue', 'optionalValue']),
      );
    });

    test('serialization includes package name', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'hello',
      );
      final state = TestResourceState(
        resource: resource,
        testValue: 'hello',
      );

      final json = ResourceStateSerialization.toJson(state);

      // Should have .type field with qualified name
      expect(json['.type'], contains('TestResourceState'));
    });

    test('can serialize ResourceState with list properties', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'value',
      );
      final state = TestResourceStateWithList(
        resource: resource,
        items: ['a', 'b', 'c'],
      );

      final json = ResourceStateSerialization.toJson(state);

      expect(json['items'], isA<List>());
      final items = json['items'] as List;
      expect(items, equals(['a', 'b', 'c']));
    });
  });

  group('ResourceState Deserialization', () {
    test('can deserialize ResourceState from JSON', () {
      final json = {
        '.type': 'TestResourceState',
        'resource': {
          '.type': 'TestResource',
          'id': 'test.resource',
          'dependencies': [],
          'testValue': 'hello',
          'optionalValue': 42,
        },
        'testValue': 'hello',
        'optionalValue': 42,
      };

      final state = ResourceStateSerialization.fromJson(
        json,
        (id) => throw StateError('Dependency "$id" not found in test'),
      );

      expect(state, isA<TestResourceState>());
      expect(state.resourceId, equals('test.resource'));
      final testState = state as TestResourceState;
      expect(testState.testValue, equals('hello'));
      expect(testState.optionalValue, equals(42));
    });

    test('can deserialize ResourceState with null values', () {
      final json = {
        '.type': 'TestResourceState',
        'resource': {
          '.type': 'TestResource',
          'id': 'test.resource',
          'dependencies': [],
          'testValue': 'hello',
        },
        'testValue': 'hello',
        'optionalValue': null,
      };

      final state = ResourceStateSerialization.fromJson(
        json,
        (id) => throw StateError('Dependency "$id" not found in test'),
      );

      expect(state, isA<TestResourceState>());
      final testState = state as TestResourceState;
      expect(testState.testValue, equals('hello'));
      expect(testState.optionalValue, isNull);
    });

    test('round-trip serialization and deserialization', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'hello',
        optionalValue: 42,
      );
      final original = TestResourceState(
        resource: resource,
        testValue: 'hello',
        optionalValue: 42,
      );

      final json = ResourceStateSerialization.toJson(original);
      final deserialized = ResourceStateSerialization.fromJson(
        json,
        (id) => throw StateError('Dependency "$id" not found in test'),
      );

      expect(deserialized, isA<TestResourceState>());
      final testState = deserialized as TestResourceState;
      expect(testState.resourceId, equals(original.resourceId));
      expect(testState.testValue, equals(original.testValue));
      expect(testState.optionalValue, equals(original.optionalValue));
    });

    test('can deserialize ResourceState with list properties', () {
      final json = {
        '.type': 'TestResourceStateWithList',
        'resource': {
          '.type': 'TestResource',
          'id': 'test.resource',
          'dependencies': [],
          'testValue': 'value',
        },
        'items': ['a', 'b', 'c'],
      };

      final state = ResourceStateSerialization.fromJson(
        json,
        (id) => throw StateError('Dependency "$id" not found in test'),
      );

      expect(state, isA<TestResourceStateWithList>());
      final testState = state as TestResourceStateWithList;
      expect(testState.items, equals(['a', 'b', 'c']));
    });

    test('falls back to basic ResourceState for unknown class', () {
      final json = {
        '.type': 'UnknownResourceState',
        'resource': {
          '.type': 'TestResource',
          'id': 'test.resource',
          'dependencies': [],
          'testValue': 'value',
        },
      };

      final state = ResourceStateSerialization.fromJson(
        json,
        (id) => throw StateError('Dependency "$id" not found in test'),
      );

      // Should fall back to basic ResourceState
      expect(state, isA<ResourceState>());
      expect(state.resourceId, equals('test.resource'));
    });

    test('throws error if type field is missing', () {
      final json = {
        'resource': {
          '.type': 'TestResource',
          'id': 'test.resource',
          'dependencies': [],
          'testValue': 'value',
        },
      };

      expect(
        () => ResourceStateSerialization.fromJson(
          json,
          (id) => throw StateError('Dependency "$id" not found in test'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('can deserialize using ResourceStateSerialization.fromJson', () {
      final json = {
        '.type': 'TestResourceState',
        'resource': {
          '.type': 'TestResource',
          'id': 'test.resource',
          'dependencies': [],
          'testValue': 'hello',
          'optionalValue': 42,
        },
        'testValue': 'hello',
        'optionalValue': 42,
      };

      final state = ResourceStateSerialization.fromJson(
        json,
        (id) => throw StateError('Dependency "$id" not found in test'),
      );

      expect(state, isA<TestResourceState>());
      expect(state.resourceId, equals('test.resource'));
      final testState = state as TestResourceState;
      expect(testState.testValue, equals('hello'));
      expect(testState.optionalValue, equals(42));
    });

    test('round-trip using ResourceStateSerialization', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'hello',
        optionalValue: 42,
      );
      final original = TestResourceState(
        resource: resource,
        testValue: 'hello',
        optionalValue: 42,
      );

      final json = ResourceStateSerialization.toJson(original);
      final deserialized = ResourceStateSerialization.fromJson(
        json,
        (id) => throw StateError('Dependency "$id" not found in test'),
      );

      expect(deserialized, isA<TestResourceState>());
      final testState = deserialized as TestResourceState;
      expect(testState.resourceId, equals(original.resourceId));
      expect(testState.testValue, equals(original.testValue));
      expect(testState.optionalValue, equals(original.optionalValue));
    });
  });
}

/// Test resource for testing serialization and deserialization
class TestResource extends Resource<TestResourceState> {
  final String testValue;
  final int? optionalValue;

  const TestResource({
    required super.id,
    required this.testValue,
    this.optionalValue,
    super.dependencies,
  });
}

/// Test resource state for testing serialization and deserialization
class TestResourceState extends ResourceState {
  final String testValue;
  final int? optionalValue;

  TestResourceState({
    required super.resource,
    this.testValue = 'value',
    this.optionalValue,
  });
}

/// Test resource state with list property
class TestResourceStateWithList extends ResourceState {
  final List<String> items;

  TestResourceStateWithList({
    required super.resource,
    required this.items,
  });
}
