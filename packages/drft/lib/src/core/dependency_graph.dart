/// Dependency graph for managing resource dependencies
library;

import '../utils/exceptions.dart';
import 'resource.dart';

/// Represents a dependency graph of resources
class DependencyGraph {
  final Map<String, Set<String>> _dependencies = {};
  final Map<String, Set<String>> _dependents = {};

  /// Add a resource and its dependencies
  void addResource(Resource resource) {
    final resourceId = resource.id;

    // Initialize sets if not present
    _dependencies.putIfAbsent(resourceId, () => <String>{});
    _dependents.putIfAbsent(resourceId, () => <String>{});

    // Add explicit dependencies (extract IDs from Resource references)
    for (final dep in resource.dependencies) {
      final depId = dep.id;
      _dependencies[resourceId]!.add(depId);
      _dependents.putIfAbsent(depId, () => <String>{}).add(resourceId);
    }
  }

  /// Add multiple resources
  void addResources(List<Resource> resources) {
    for (final resource in resources) {
      addResource(resource);
    }
  }

  /// Get dependencies for a resource
  Set<String> getDependencies(String resourceId) {
    return _dependencies[resourceId] ?? <String>{};
  }

  /// Get dependents (resources that depend on this one)
  Set<String> getDependents(String resourceId) {
    return _dependents[resourceId] ?? <String>{};
  }

  /// Get all resources in the graph
  ///
  /// Only includes resources that were explicitly added via [addResource] or [addResources].
  /// Dependencies that are referenced but not explicitly added are not included.
  Set<String> get allResources => _dependencies.keys.toSet();

  /// Get topological sort order (resources that can be processed first)
  /// Returns resources in order: those with no dependencies first
  List<String> topologicalSort() {
    final result = <String>[];
    final inDegree = <String, int>{};
    final queue = <String>[];

    // Initialize in-degree for all explicitly added resources
    // Only count dependencies that are also in the graph (explicitly added)
    for (final resourceId in allResources) {
      final dependencies = getDependencies(resourceId);
      // Only count dependencies that are also in the graph
      final inGraphDependencies =
          dependencies.where((depId) => allResources.contains(depId));
      inDegree[resourceId] = inGraphDependencies.length;
      if (inDegree[resourceId] == 0) {
        queue.add(resourceId);
      }
    }

    // Process resources with no dependencies
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      result.add(current);

      // Reduce in-degree for dependents (only those in the graph)
      for (final dependent in getDependents(current)) {
        if (allResources.contains(dependent)) {
          inDegree[dependent] = (inDegree[dependent] ?? 0) - 1;
          if (inDegree[dependent] == 0) {
            queue.add(dependent);
          }
        }
      }
    }

    // With Resource references, circular dependencies are impossible at compile time.
    // If result.length != allResources.length, it indicates a bug in the graph construction.
    assert(
      result.length == allResources.length,
      'Graph construction error: not all resources processed. '
      'This should never happen with Resource references.',
    );

    return result;
  }

  /// Get reverse topological sort (for deletion order)
  /// Returns resources in order: those with no dependents first
  ///
  /// For a DAG, this is simply the reverse of the topological sort.
  List<String> reverseTopologicalSort() {
    final order = topologicalSort();
    return order.reversed.toList();
  }

  /// Validate that all dependencies are present in the graph
  ///
  /// Throws [DrftException] if any resource depends on another resource
  /// that is not explicitly added to the graph.
  ///
  /// This helps catch configuration errors where a resource references
  /// a dependency that isn't being managed.
  void validateDependencies() {
    final missingDependencies = <String, Set<String>>{};

    for (final resourceId in allResources) {
      final dependencies = getDependencies(resourceId);
      final missing =
          dependencies.where((depId) => !allResources.contains(depId));
      if (missing.isNotEmpty) {
        missingDependencies[resourceId] = missing.toSet();
      }
    }

    if (missingDependencies.isNotEmpty) {
      final messages = missingDependencies.entries.map((entry) {
        final missingList = entry.value.join(', ');
        return 'Resource "${entry.key}" depends on missing resources: $missingList';
      });
      throw DrftException(
        'Missing dependencies detected:\n${messages.join('\n')}\n\n'
        'All resources referenced in dependencies must be explicitly added to the stack.',
      );
    }
  }
}
