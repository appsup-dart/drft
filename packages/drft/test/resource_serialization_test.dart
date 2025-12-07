import 'package:drft/drft.dart';
import 'package:drft/src/core/resource_serialization.dart';
import 'package:test/test.dart';

void main() {
  group('Resource Serialization', () {
    test('can serialize resource with final members', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'hello',
        optionalValue: 42,
      );

      final json = ResourceSerialization.toJson(resource);

      // Metadata fields
      expect(json['.type'], contains('TestResource'));
      expect(json['id'], equals('test.resource'));
      expect(json['dependencies'], isA<List>());

      // Properties at top level
      expect(json['testValue'], equals('hello'));
      expect(json['optionalValue'], equals(42));
    });

    test('can serialize resource with null values', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'hello',
        optionalValue: null,
      );

      final json = ResourceSerialization.toJson(resource);

      expect(json['testValue'], equals('hello'));
      expect(json['optionalValue'], isNull);
    });

    test('serialization includes all public fields', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'test',
        optionalValue: 123,
      );

      final json = ResourceSerialization.toJson(resource);

      // Check for metadata and properties
      expect(
        json.keys,
        containsAll(
          ['.type', 'id', 'dependencies', 'testValue', 'optionalValue'],
        ),
      );
    });

    test('serialization includes qualified type name', () {
      final resource = const TestResource(
        id: 'test.resource',
        testValue: 'hello',
      );

      final json = ResourceSerialization.toJson(resource);

      // Should have .type field with qualified name
      expect(json['.type'], contains('TestResource'));
    });
  });

  group('Resource Deserialization', () {
    test('can deserialize resource from JSON', () {
      final json = {
        '.type': 'TestResource',
        'id': 'test.resource',
        'dependencies': [],
        'testValue': 'hello',
        'optionalValue': 42,
      };

      final resource = ResourceSerialization.fromJson(
        json,
        (id) => throw StateError('Dependency "$id" not found in test'),
      );

      expect(resource, isA<TestResource>());
      expect(resource.id, equals('test.resource'));
      final testResource = resource as TestResource;
      expect(testResource.testValue, equals('hello'));
      expect(testResource.optionalValue, equals(42));
    });

    test('can deserialize resource with null values', () {
      final json = {
        '.type': 'TestResource',
        'id': 'test.resource',
        'dependencies': [],
        'testValue': 'hello',
        'optionalValue': null,
      };

      final resource = ResourceSerialization.fromJson(
        json,
        (id) => throw StateError('Dependency "$id" not found in test'),
      );

      expect(resource, isA<TestResource>());
      final testResource = resource as TestResource;
      expect(testResource.testValue, equals('hello'));
      expect(testResource.optionalValue, isNull);
    });

    test('can deserialize resource with dependencies', () {
      final json = {
        '.type': 'TestResource',
        'id': 'test.resource',
        'dependencies': ['resource1', 'resource2'],
        'testValue': 'hello',
      };

      // When deserializing with dependencies, getDependency must be able to find them
      // or it will throw. For this test, we'll provide mock dependencies.
      final dep1 = const TestResource(id: 'resource1', testValue: 'dep1');
      final dep2 = const TestResource(id: 'resource2', testValue: 'dep2');
      final resource = ResourceSerialization.fromJson(
        json,
        (id) {
          if (id == 'resource1') return dep1;
          if (id == 'resource2') return dep2;
          throw StateError('Dependency "$id" not found in test');
        },
      );

      expect(resource, isA<TestResource>());
      expect(resource.dependencies, hasLength(2));
      expect(
        resource.dependencies.map((r) => r.id),
        containsAll(['resource1', 'resource2']),
      );
    });

    test('round-trip serialization and deserialization', () {
      final original = const TestResource(
        id: 'test.resource',
        testValue: 'hello',
        optionalValue: 42,
      );

      final json = ResourceSerialization.toJson(original);
      final deserialized = ResourceSerialization.fromJson(
        json,
        (id) => throw StateError('Dependency "$id" not found in test'),
      );

      expect(deserialized, isA<TestResource>());
      final testResource = deserialized as TestResource;
      expect(testResource.id, equals(original.id));
      expect(testResource.testValue, equals(original.testValue));
      expect(testResource.optionalValue, equals(original.optionalValue));
      expect(testResource.dependencies, equals(original.dependencies));
    });

    test('throws error for unknown resource class', () {
      final json = {
        '.type': 'UnknownResource',
        'id': 'test.resource',
        'dependencies': [],
      };

      expect(
        () => ResourceSerialization.fromJson(
          json,
          (id) => throw StateError('Dependency "$id" not found in test'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws error if type field is missing', () {
      final json = {
        'id': 'test.resource',
        'dependencies': [],
      };

      expect(
        () => ResourceSerialization.fromJson(
          json,
          (id) => throw StateError('Dependency "$id" not found in test'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

/// Test resource for testing serialization and deserialization
class TestResource extends Resource {
  final String testValue;
  final int? optionalValue;

  const TestResource({
    required super.id,
    this.testValue = 'value',
    this.optionalValue,
    super.dependencies = const [],
  });
}
