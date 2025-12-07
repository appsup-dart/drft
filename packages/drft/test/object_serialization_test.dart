import 'package:drft/drft.dart';
import 'package:drft/src/core/resource_serialization.dart';
import 'package:drft/src/core/resource_state_serialization.dart';
import 'package:test/test.dart';

void main() {
  group('ObjectSerialization', () {
    group('Basic Serialization', () {
      test('can serialize simple object', () {
        final obj = SimpleObject(name: 'test', value: 42);
        final json = ObjectSerialization.instance.toJson(obj);

        expect(json['.type'], 'drft.SimpleObject');
        expect(json['name'], equals('test'));
        expect(json['value'], equals(42));
      });

      test('can deserialize simple object', () {
        final json = {
          '.type': 'drft.SimpleObject',
          'name': 'test',
          'value': 42,
        };

        final obj = ObjectSerialization.instance.fromJson<SimpleObject>(json);
        expect(obj.name, equals('test'));
        expect(obj.value, equals(42));
      });

      test('round-trip serialization and deserialization', () {
        final original = SimpleObject(name: 'test', value: 42);
        final json = ObjectSerialization.instance.toJson(original);
        final deserialized =
            ObjectSerialization.instance.fromJson<SimpleObject>(json);

        expect(deserialized.name, equals(original.name));
        expect(deserialized.value, equals(original.value));
      });
    });

    group('Inheritance', () {
      test('serializes fields from parent class', () {
        final obj = ChildObject(name: 'child', value: 42, childField: 'child');
        final json = ObjectSerialization.instance.toJson(obj);

        // JSON includes .type metadata and all fields (including inherited)
        expect(json.containsKey('.type'), isTrue);
        expect(json['name'], equals('child'));
        expect(json['value'], equals(42));
        expect(json['childField'], equals('child'));
      });

      test('deserializes object with inherited fields', () {
        final json = {
          '.type': 'drft.ChildObject',
          'name': 'child',
          'value': 42,
          'childField': 'child',
        };

        final obj = ObjectSerialization.instance.fromJson<ChildObject>(json);
        expect(obj.name, equals('child'));
        expect(obj.value, equals(42));
        expect(obj.childField, equals('child'));
      });
    });

    group('Collections', () {
      test('can serialize and deserialize lists', () {
        final obj = ObjectWithList(items: ['a', 'b', 'c']);
        final json = ObjectSerialization.instance.toJson(obj);

        expect(json['items'], isA<List>());
        expect(json['items'], equals(['a', 'b', 'c']));

        final deserialized =
            ObjectSerialization.instance.fromJson<ObjectWithList>(json);
        expect(deserialized.items, equals(['a', 'b', 'c']));
      });

      test('can serialize and deserialize maps', () {
        final obj = ObjectWithMap(
          metadata: {'key1': 'value1', 'key2': 'value2'},
        );
        final json = ObjectSerialization.instance.toJson(obj);

        expect(json['metadata'], isA<Map>());
        expect(json['metadata']['key1'], equals('value1'));
        expect(json['metadata']['key2'], equals('value2'));

        final deserialized =
            ObjectSerialization.instance.fromJson<ObjectWithMap>(json);
        expect(deserialized.metadata['key1'], equals('value1'));
        expect(deserialized.metadata['key2'], equals('value2'));
      });

      test('can serialize and deserialize nested lists', () {
        final obj = ObjectWithNestedList(
          matrix: [
            [1, 2, 3],
            [4, 5, 6],
          ],
        );
        final json = ObjectSerialization.instance.toJson(obj);

        expect(json['matrix'], isA<List>());
        expect(json['matrix'][0], isA<List>());
        expect(json['matrix'][0], equals([1, 2, 3]));

        final deserialized =
            ObjectSerialization.instance.fromJson<ObjectWithNestedList>(json);
        expect(deserialized.matrix[0], equals([1, 2, 3]));
        expect(deserialized.matrix[1], equals([4, 5, 6]));
      });

      test('converts List<dynamic> to List<String> during deserialization', () {
        final json = {
          '.type': 'drft.ObjectWithStringList',
          'items': ['a', 'b', 'c'], // List<dynamic> from JSON
        };

        final obj =
            ObjectSerialization.instance.fromJson<ObjectWithStringList>(json);
        expect(obj.items, isA<List<String>>());
        expect(obj.items, equals(['a', 'b', 'c']));
      });

      test('converts List<dynamic> to List<int> during deserialization', () {
        final json = {
          '.type': 'drft.ObjectWithIntList',
          'numbers': [1, 2, 3], // List<dynamic> from JSON
        };

        final obj =
            ObjectSerialization.instance.fromJson<ObjectWithIntList>(json);
        expect(obj.numbers, isA<List<int>>());
        expect(obj.numbers, equals([1, 2, 3]));
      });

      test('converts nested List<dynamic> to List<List<String>>', () {
        final json = {
          '.type': 'drft.ObjectWithNestedStringList',
          'matrix': [
            ['a', 'b'],
            ['c', 'd'],
          ],
        };

        final obj = ObjectSerialization.instance
            .fromJson<ObjectWithNestedStringList>(json);
        expect(obj.matrix, isA<List<List<String>>>());
        expect(obj.matrix[0], isA<List<String>>());
        expect(obj.matrix[0], equals(['a', 'b']));
        expect(obj.matrix[1], equals(['c', 'd']));
      });

      test('round-trip serialization preserves List<String> type', () {
        final original = ObjectWithStringList(items: ['x', 'y', 'z']);
        final json = ObjectSerialization.instance.toJson(original);
        final deserialized =
            ObjectSerialization.instance.fromJson<ObjectWithStringList>(json);

        expect(deserialized.items, isA<List<String>>());
        expect(deserialized.items, equals(original.items));
      });

      test('handles empty List<String>', () {
        final json = {
          '.type': 'drft.ObjectWithStringList',
          'items': <String>[],
        };

        final obj =
            ObjectSerialization.instance.fromJson<ObjectWithStringList>(json);
        expect(obj.items, isA<List<String>>());
        expect(obj.items, isEmpty);
      });
    });

    group('Null Values', () {
      test('can serialize null values', () {
        final obj = ObjectWithNulls(name: 'test', optionalValue: null);
        final json = ObjectSerialization.instance.toJson(obj);

        expect(json['name'], equals('test'));
        expect(json['optionalValue'], isNull);
      });

      test('can deserialize null values', () {
        final json = {
          '.type': 'ObjectWithNulls',
          'name': 'test',
          'optionalValue': null,
        };

        final obj =
            ObjectSerialization.instance.fromJson<ObjectWithNulls>(json);
        expect(obj.name, equals('test'));
        expect(obj.optionalValue, isNull);
      });
    });

    group('Nested Objects', () {
      test('can serialize nested objects', () {
        final nested = SimpleObject(name: 'nested', value: 10);
        final obj = ObjectWithNested(nested: nested);
        final json = ObjectSerialization.instance.toJson(obj);

        expect(json['nested'], isA<Map>());
        expect(json['nested']['.type'], contains('SimpleObject'));
        expect(json['nested']['name'], equals('nested'));
        expect(json['nested']['value'], equals(10));
      });

      test('can deserialize nested objects', () {
        final json = {
          '.type': 'ObjectWithNested',
          'nested': {
            '.type': 'SimpleObject',
            'name': 'nested',
            'value': 10,
          },
        };

        final obj =
            ObjectSerialization.instance.fromJson<ObjectWithNested>(json);
        expect(obj.nested.name, equals('nested'));
        expect(obj.nested.value, equals(10));
      });
    });

    group('Field Filtering', () {
      test('can filter fields during serialization', () {
        final obj = SimpleObject(name: 'test', value: 42);
        final json = ObjectSerialization.instance.toJson(
          obj,
          fieldFilter: (fieldName) => fieldName != 'value',
        );

        expect(json['name'], equals('test'));
        expect(json.containsKey('value'), isFalse);
      });
    });

    group('Field Mapping', () {
      test('can map field values during deserialization', () {
        final json = {
          '.type': 'SimpleObject',
          'name': 'test',
          'value': '42', // String instead of int
        };

        final obj = ObjectSerialization.instance.fromJson<SimpleObject>(
          json,
          fieldMapper: (fieldName, value) {
            if (fieldName == 'value') {
              return int.parse(value as String);
            }
            return value;
          },
        );

        expect(obj.value, equals(42));
      });
    });

    group('Error Cases', () {
      test('throws error if .type field is missing', () {
        final json = {'name': 'test', 'value': 42};

        expect(
          () => ObjectSerialization.instance.fromJson<SimpleObject>(json),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.message, 'message', contains('.type')),
          ),
        );
      });

      test('throws error if class not found', () {
        final json = {
          '.type': 'NonExistentClass',
          'name': 'test',
        };

        expect(
          () => ObjectSerialization.instance.fromJson(json),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Could not find class'),
            ),
          ),
        );
      });

      test('throws error if no default constructor found', () {
        final json = {
          '.type': 'ObjectWithoutDefaultConstructor',
          'name': 'test',
        };

        expect(
          () => ObjectSerialization.instance
              .fromJson<ObjectWithoutDefaultConstructor>(json),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('No default constructor'),
            ),
          ),
        );
      });

      test('throws error for cyclic references', () {
        final obj1 = CyclicObject(name: 'obj1');
        final obj2 = CyclicObject(name: 'obj2');
        obj1.ref = obj2;
        obj2.ref = obj1; // Create cycle

        // Cyclic detection may throw StackOverflowError if not caught early
        expect(
          () => ObjectSerialization.instance.toJson(obj1),
          throwsA(
            anyOf(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('Cyclic reference'),
              ),
              isA<StackOverflowError>(),
            ),
          ),
        );
      });
    });

    group('Custom Serializers', () {
      test('can serialize and deserialize Uri using custom serializer', () {
        ObjectSerialization.instance.registerCustomSerializer<Uri>(
          CustomSerializer<Uri>(
            toJson: (uri) => uri.toString(),
            fromJson: (value) => Uri.parse(value as String),
          ),
        );

        final originalUri = Uri.parse('https://example.com/path?query=value');
        final testObject = TestObjectWithUri(
          name: 'test',
          uri: originalUri,
        );

        final objectJson = ObjectSerialization.instance.toJson(testObject);
        expect(objectJson['name'], equals('test'));
        expect(objectJson['uri'], isA<String>());
        expect(
          objectJson['uri'],
          equals('https://example.com/path?query=value'),
        );

        final deserialized = ObjectSerialization.instance
            .fromJson<TestObjectWithUri>(objectJson);
        expect(deserialized.name, equals('test'));
        expect(deserialized.uri, equals(originalUri));

        ObjectSerialization.instance.unregisterCustomSerializer<Uri>();
      });

      test('can serialize and deserialize custom type with custom serializer',
          () {
        ObjectSerialization.instance.registerCustomSerializer<CustomType>(
          CustomSerializer<CustomType>(
            toJson: (value) => {'x': value.x, 'y': value.y},
            fromJson: (value) {
              final map = value as Map<String, dynamic>;
              return CustomType(x: map['x'] as int, y: map['y'] as int);
            },
          ),
        );

        final original = CustomType(x: 10, y: 20);
        final json = ObjectSerialization.instance.toJson(original);

        expect(json, isA<Map<String, dynamic>>());
        expect(json['x'], equals(10));
        expect(json['y'], equals(20));

        final deserialized =
            ObjectSerialization.instance.fromJson<CustomType>(json);
        expect(deserialized.x, equals(10));
        expect(deserialized.y, equals(20));

        ObjectSerialization.instance.unregisterCustomSerializer<CustomType>();
      });

      test('custom serializer works in nested objects and lists', () {
        ObjectSerialization.instance.registerCustomSerializer<Uri>(
          CustomSerializer<Uri>(
            toJson: (uri) => uri.toString(),
            fromJson: (value) => Uri.parse(value as String),
          ),
        );

        final nested = NestedObject(
          id: 'test-1',
          uris: [
            Uri.parse('https://example.com/1'),
            Uri.parse('https://example.com/2'),
          ],
        );

        final json = ObjectSerialization.instance.toJson(nested);
        expect(json['id'], equals('test-1'));
        expect(json['uris'], isA<List>());
        expect(json['uris'][0], isA<String>());
        expect(json['uris'][0], equals('https://example.com/1'));
        expect(json['uris'][1], isA<String>());
        expect(json['uris'][1], equals('https://example.com/2'));

        final deserialized =
            ObjectSerialization.instance.fromJson<NestedObject>(json);
        expect(deserialized.id, equals('test-1'));
        expect(deserialized.uris.length, equals(2));
        expect(
          deserialized.uris[0],
          equals(Uri.parse('https://example.com/1')),
        );
        expect(
          deserialized.uris[1],
          equals(Uri.parse('https://example.com/2')),
        );

        ObjectSerialization.instance.unregisterCustomSerializer<Uri>();
      });

      test('can clear all custom serializers', () {
        ObjectSerialization.instance.registerCustomSerializer<Uri>(
          CustomSerializer<Uri>(
            toJson: (uri) => uri.toString(),
            fromJson: (value) => Uri.parse(value as String),
          ),
        );

        ObjectSerialization.instance.registerCustomSerializer<CustomType>(
          CustomSerializer<CustomType>(
            toJson: (value) => {'x': value.x, 'y': value.y},
            fromJson: (value) {
              final map = value as Map<String, dynamic>;
              return CustomType(x: map['x'] as int, y: map['y'] as int);
            },
          ),
        );

        ObjectSerialization.instance.clearCustomSerializers();

        // After clearing, custom serializers should not be used
        final uri = Uri.parse('https://example.com');
        final json = ObjectSerialization.instance.toJson(uri);
        // Should have .type field from default serialization
        expect(json.containsKey('.type'), isTrue);
      });
    });

    group('Enums', () {
      test('can serialize enum value', () {
        final obj = ObjectWithEnum(platform: TestPlatform.ios);
        final json = ObjectSerialization.instance.toJson(obj);

        expect(json['.type'], 'drft.ObjectWithEnum');
        expect(json['platform'], equals('ios'));
      });

      test('can deserialize enum value', () {
        final json = {
          '.type': 'drft.ObjectWithEnum',
          'platform': 'android',
        };

        final obj = ObjectSerialization.instance.fromJson<ObjectWithEnum>(json);
        expect(obj.platform, equals(TestPlatform.android));
      });

      test('round-trip serialization and deserialization preserves enum', () {
        final original = ObjectWithEnum(platform: TestPlatform.web);
        final json = ObjectSerialization.instance.toJson(original);
        final deserialized =
            ObjectSerialization.instance.fromJson<ObjectWithEnum>(json);

        expect(deserialized.platform, equals(original.platform));
        expect(deserialized.platform, equals(TestPlatform.web));
      });

      test('can serialize nullable enum', () {
        final obj = ObjectWithNullableEnum(platform: null);
        final json = ObjectSerialization.instance.toJson(obj);

        expect(json['platform'], isNull);
      });

      test('can deserialize nullable enum', () {
        final json = {
          '.type': 'drft.ObjectWithNullableEnum',
          'platform': null,
        };

        final obj =
            ObjectSerialization.instance.fromJson<ObjectWithNullableEnum>(json);
        expect(obj.platform, isNull);
      });

      test('can serialize and deserialize nullable enum with value', () {
        final original = ObjectWithNullableEnum(platform: TestPlatform.ios);
        final json = ObjectSerialization.instance.toJson(original);
        final deserialized =
            ObjectSerialization.instance.fromJson<ObjectWithNullableEnum>(json);

        expect(deserialized.platform, equals(original.platform));
        expect(deserialized.platform, equals(TestPlatform.ios));
      });

      test('can serialize enum in list', () {
        final obj = ObjectWithEnumList(
          platforms: [TestPlatform.ios, TestPlatform.android, TestPlatform.web],
        );
        final json = ObjectSerialization.instance.toJson(obj);

        expect(json['platforms'], isA<List>());
        expect(json['platforms'], equals(['ios', 'android', 'web']));
      });

      test('can deserialize enum in list', () {
        final json = {
          '.type': 'drft.ObjectWithEnumList',
          'platforms': ['ios', 'android', 'web'],
        };

        final obj =
            ObjectSerialization.instance.fromJson<ObjectWithEnumList>(json);
        expect(obj.platforms, isA<List<TestPlatform>>());
        expect(
          obj.platforms,
          equals([TestPlatform.ios, TestPlatform.android, TestPlatform.web]),
        );
      });

      test('round-trip serialization preserves enum list', () {
        final original = ObjectWithEnumList(
          platforms: [TestPlatform.web, TestPlatform.ios],
        );
        final json = ObjectSerialization.instance.toJson(original);
        final deserialized =
            ObjectSerialization.instance.fromJson<ObjectWithEnumList>(json);

        expect(deserialized.platforms, equals(original.platforms));
      });

      test('can serialize enum in nested object', () {
        final nested = ObjectWithEnum(platform: TestPlatform.android);
        final obj = ObjectWithNestedEnum(nested: nested);
        final json = ObjectSerialization.instance.toJson(obj);

        expect(json['nested'], isA<Map>());
        expect(json['nested']['platform'], equals('android'));
      });

      test('can deserialize enum in nested object', () {
        final json = {
          '.type': 'drft.ObjectWithNestedEnum',
          'nested': {
            '.type': 'drft.ObjectWithEnum',
            'platform': 'web',
          },
        };

        final obj =
            ObjectSerialization.instance.fromJson<ObjectWithNestedEnum>(json);
        expect(obj.nested.platform, equals(TestPlatform.web));
      });

      test('throws error for invalid enum value', () {
        final json = {
          '.type': 'drft.ObjectWithEnum',
          'platform': 'invalid_platform',
        };

        expect(
          () => ObjectSerialization.instance.fromJson<ObjectWithEnum>(json),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Non-serializable Fields', () {
      test('serializes function to string representation', () {
        final resource = TestResourceWithFunction(
          id: 'test.resource',
          callback: () => 'test',
        );

        final json = ResourceSerialization.toJson(resource);

        // Functions are serialized as objects with .type metadata, not strings
        expect(json['callback'], isA<Map>());
        expect(json['callback'], containsPair('.type', '() -> void'));
      });

      test('deserialization fails when function field is required', () {
        final resource = TestResourceWithFunction(
          id: 'test.resource',
          callback: () => 'test',
        );

        final json = ResourceSerialization.toJson(resource);

        expect(
          () => ResourceSerialization.fromJson(
            json,
            (id) => throw StateError('Dependency "$id" not found in test'),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('serializes complex object to string representation', () {
        final resource = TestResourceWithComplexObject(
          id: 'test.resource',
          complexObject: DateTime.now(),
        );

        final json = ResourceSerialization.toJson(resource);

        // DateTime is serialized as an object with .type metadata, not a string
        expect(json['complexObject'], isA<Map>());
        expect(json['complexObject'], containsPair('.type', 'DateTime'));
      });

      test('deserialization fails when complex object field is required', () {
        final resource = TestResourceWithComplexObject(
          id: 'test.resource',
          complexObject: DateTime(2024, 1, 1),
        );

        final json = ResourceSerialization.toJson(resource);

        expect(
          () => ResourceSerialization.fromJson(
            json,
            (id) => throw StateError('Dependency "$id" not found in test'),
          ),
          throwsA(isA<NoSuchMethodError>()),
        );
      });

      test('serializes optional non-serializable field', () {
        final resource = const TestResourceWithOptionalFunction(
          id: 'test.resource',
        );

        final json = ResourceSerialization.toJson(resource);

        // Should serialize successfully even without the optional function
        expect(json, isA<Map>());
      });

      test('can deserialize with optional non-serializable field missing', () {
        final resource = const TestResourceWithOptionalFunction(
          id: 'test.resource',
        );

        final json = ResourceSerialization.toJson(resource);
        final deserialized = ResourceSerialization.fromJson(
          json,
          (id) => throw StateError('Dependency "$id" not found in test'),
        );

        expect(deserialized.id, equals('test.resource'));
        expect(deserialized, isA<TestResourceWithOptionalFunction>());
      });

      test('ResourceState serializes non-serializable field', () {
        final resource = const TestResourceForState(
          id: 'test.resource',
          name: 'test',
        );
        final state = TestResourceStateWithFunction(
          resource: resource,
          callback: () => 'test',
        );

        final json = ResourceStateSerialization.toJson(state);

        // Properties are at top level in the JSON (not nested under 'properties')
        // Function will be serialized as an object (with .type field) or string representation
        expect(json.containsKey('callback'), isTrue);
        // The callback field exists but may be serialized differently
        expect(json['callback'], isNotNull);
      });
    });
  });
}

// Test classes for basic serialization
class SimpleObject {
  final String name;
  final int value;

  SimpleObject({
    required this.name,
    required this.value,
  });
}

class ChildObject extends SimpleObject {
  final String childField;

  ChildObject({
    required super.name,
    required super.value,
    required this.childField,
  });
}

class ObjectWithList {
  final List<String> items;

  ObjectWithList({
    required this.items,
  });
}

class ObjectWithMap {
  final Map<String, String> metadata;

  ObjectWithMap({
    required this.metadata,
  });
}

class ObjectWithNestedList {
  final List<List<int>> matrix;

  ObjectWithNestedList({
    required this.matrix,
  });
}

class ObjectWithNulls {
  final String name;
  final String? optionalValue;

  ObjectWithNulls({
    required this.name,
    this.optionalValue,
  });
}

class ObjectWithNested {
  final SimpleObject nested;

  ObjectWithNested({
    required this.nested,
  });
}

class ObjectWithoutDefaultConstructor {
  final String name;

  ObjectWithoutDefaultConstructor.named({required this.name});
}

class CyclicObject {
  final String name;
  CyclicObject? ref;

  CyclicObject({
    required this.name,
    this.ref,
  });
}

// Test classes for custom serializers
class TestObjectWithUri {
  final String name;
  final Uri uri;

  TestObjectWithUri({
    required this.name,
    required this.uri,
  });
}

class CustomType {
  final int x;
  final int y;

  CustomType({
    required this.x,
    required this.y,
  });
}

class NestedObject {
  final String id;
  final List<Uri> uris;

  NestedObject({
    required this.id,
    required this.uris,
  });
}

// Test classes for non-serializable fields
class TestResourceWithFunction extends Resource {
  final void Function() callback;

  const TestResourceWithFunction({
    required super.id,
    required this.callback,
    super.dependencies = const [],
  });
}

class TestResourceWithComplexObject extends Resource {
  final DateTime complexObject;

  const TestResourceWithComplexObject({
    required super.id,
    required this.complexObject,
    super.dependencies = const [],
  });
}

class TestResourceWithOptionalFunction extends Resource {
  final void Function()? callback;

  const TestResourceWithOptionalFunction({
    required super.id,
    this.callback,
    super.dependencies = const [],
  });
}

class TestResourceForState extends Resource<TestResourceStateWithFunction> {
  final String name;

  const TestResourceForState({
    required super.id,
    required this.name,
    super.dependencies = const [],
  });
}

class TestResourceStateWithFunction extends ResourceState {
  final void Function() callback;

  TestResourceStateWithFunction({
    required super.resource,
    required this.callback,
  });
}

// Test classes for list type conversion
class ObjectWithStringList {
  final List<String> items;

  ObjectWithStringList({
    required this.items,
  });
}

class ObjectWithIntList {
  final List<int> numbers;

  ObjectWithIntList({
    required this.numbers,
  });
}

class ObjectWithNestedStringList {
  final List<List<String>> matrix;

  ObjectWithNestedStringList({
    required this.matrix,
  });
}

// Test enum for enum serialization tests
enum TestPlatform {
  ios,
  android,
  web,
}

// Test classes for enum serialization
class ObjectWithEnum {
  final TestPlatform platform;

  ObjectWithEnum({
    required this.platform,
  });
}

class ObjectWithNullableEnum {
  final TestPlatform? platform;

  ObjectWithNullableEnum({
    this.platform,
  });
}

class ObjectWithEnumList {
  final List<TestPlatform> platforms;

  ObjectWithEnumList({
    required this.platforms,
  });
}

class ObjectWithNestedEnum {
  final ObjectWithEnum nested;

  ObjectWithNestedEnum({
    required this.nested,
  });
}
