import 'package:drft/drft.dart';
import 'package:test/test.dart';

void main() {
  group('DependencyGraph', () {
    test('can add resources and track dependencies', () {
      final graph = DependencyGraph();
      final resource1 = const TestResource(id: 'resource1');
      final resource2 =
          TestResource(id: 'resource2', dependencies: [resource1]);

      graph.addResource(resource1);
      graph.addResource(resource2);

      expect(graph.getDependencies('resource2'), contains('resource1'));
      expect(graph.getDependents('resource1'), contains('resource2'));
    });

    test('topological sort orders dependencies first', () {
      final graph = DependencyGraph();
      final resource1 = const TestResource(id: 'resource1');
      final resource2 =
          TestResource(id: 'resource2', dependencies: [resource1]);
      final resource3 =
          TestResource(id: 'resource3', dependencies: [resource2]);

      graph.addResources([resource1, resource2, resource3]);

      final order = graph.topologicalSort();
      expect(order.indexOf('resource1'), lessThan(order.indexOf('resource2')));
      expect(order.indexOf('resource2'), lessThan(order.indexOf('resource3')));
    });

    test('reverse topological sort orders dependents first', () {
      final graph = DependencyGraph();
      final resource1 = const TestResource(id: 'resource1');
      final resource2 =
          TestResource(id: 'resource2', dependencies: [resource1]);
      final resource3 =
          TestResource(id: 'resource3', dependencies: [resource2]);

      graph.addResources([resource1, resource2, resource3]);

      final order = graph.reverseTopologicalSort();
      expect(order.indexOf('resource3'), lessThan(order.indexOf('resource2')));
      expect(order.indexOf('resource2'), lessThan(order.indexOf('resource1')));
    });

    test('handles resources with no dependencies', () {
      final graph = DependencyGraph();
      final resource1 = const TestResource(id: 'resource1');
      final resource2 = const TestResource(id: 'resource2');

      graph.addResources([resource1, resource2]);

      expect(graph.getDependencies('resource1'), isEmpty);
      expect(graph.getDependents('resource1'), isEmpty);
      expect(graph.topologicalSort(), hasLength(2));
    });

    test('throws error when dependency is not added to graph', () {
      final graph = DependencyGraph();
      final resource1 = const TestResource(id: 'resource1');
      final resource2 =
          TestResource(id: 'resource2', dependencies: [resource1]);

      // Only add resource2, not resource1
      graph.addResource(resource2);

      expect(
        () => graph.validateDependencies(),
        throwsA(
          isA<DrftException>().having(
            (e) => e.message,
            'message',
            contains(
              'Resource "resource2" depends on missing resources: resource1',
            ),
          ),
        ),
      );
    });

    test('does not throw when all dependencies are present', () {
      final graph = DependencyGraph();
      final resource1 = const TestResource(id: 'resource1');
      final resource2 =
          TestResource(id: 'resource2', dependencies: [resource1]);

      // Add both resources
      graph.addResources([resource1, resource2]);

      // Should not throw
      expect(() => graph.validateDependencies(), returnsNormally);
    });
  });
}

class TestResource extends Resource {
  const TestResource({
    required super.id,
    super.dependencies = const [],
  });
}
