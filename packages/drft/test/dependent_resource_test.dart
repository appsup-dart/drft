import 'package:drft/drft.dart';
import 'package:test/test.dart';

// Test resource state
class TestResourceState extends ResourceState {
  final String testValue;

  TestResourceState({
    required super.resource,
    required this.testValue,
  });
}

// Test resource
class TestResource extends Resource<TestResourceState> {
  final String testValue;

  const TestResource({
    required super.id,
    required this.testValue,
    super.dependencies = const [],
  });
}

// Dependency resource
class DependencyResource extends Resource<TestResourceState> {
  final String name;

  const DependencyResource({
    required super.id,
    required this.name,
    super.dependencies = const [],
  });
}

void main() {
  group('DependentResource', () {
    test('can create DependentResource with single dependency', () {
      const dependency = DependencyResource(
        id: 'dep.resource',
        name: 'dependency',
      );

      final dependent = DependentResource.single(
        id: 'test.resource',
        dependency: dependency,
        builder: (state) {
          return const TestResource(
            id: 'test.resource',
            testValue: 'built',
          );
        },
      );

      expect(dependent.id, equals('test.resource'));
      expect(dependent.dependencies, equals([dependency]));
    });

    test('can build DependentResource from dependency states', () {
      const dependency = DependencyResource(
        id: 'dep.resource',
        name: 'dependency',
      );

      final dependent = DependentResource.single(
        id: 'test.resource',
        dependency: dependency,
        builder: (state) {
          return const TestResource(
            id: 'test.resource',
            testValue: 'built',
          );
        },
      );

      final dependencyState = TestResourceState(
        resource: dependency,
        testValue: 'from-state',
      );

      final built = dependent.build([dependencyState]);

      expect(built, isA<TestResource>());
      expect(built.id, equals('test.resource'));
      expect((built as TestResource).testValue, equals('built'));
    });
  });
}
