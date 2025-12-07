/// Planning - Generate plans for infrastructure changes
library;

import 'package:collection/collection.dart';

import 'dependent_resource.dart';
import 'dependency_graph.dart';
import 'resource.dart';
import 'resource_serialization.dart';
import 'state.dart';

/// Type of operation to perform
enum OperationType {
  create,
  update,
  delete,
}

/// An operation to be performed on a resource
class Operation {
  final OperationType type;
  final Resource? resource;
  final ResourceState? currentState;

  Operation.create({
    required Resource this.resource,
  })  : type = OperationType.create,
        currentState = null;

  Operation.update({
    required ResourceState this.currentState,
    required Resource this.resource,
  }) : type = OperationType.update;

  Operation.delete({
    required ResourceState this.currentState,
  })  : type = OperationType.delete,
        resource = null;
}

/// Information about property differences
class PropertyDifference {
  final String field;
  final dynamic current;
  final dynamic desired;

  PropertyDifference({
    required this.field,
    required this.current,
    required this.desired,
  });
}

/// Verbose information about the plan
class VerbosePlanInfo {
  /// Resource IDs that are unchanged
  final List<String> unchanged;

  /// Differences for resources that need updates
  /// Key: resource ID, Value: list of property differences
  final Map<String, List<PropertyDifference>> differences;

  VerbosePlanInfo({
    required this.unchanged,
    required this.differences,
  });
}

/// A plan showing what changes will be made
class Plan {
  final List<Operation> operations;
  final Map<String, dynamic> metadata;
  final VerbosePlanInfo? _verboseInfo;

  Plan({
    required this.operations,
    this.metadata = const {},
    VerbosePlanInfo? verboseInfo,
  }) : _verboseInfo = verboseInfo;

  /// Get verbose information about the plan
  VerbosePlanInfo get verboseInfo =>
      _verboseInfo ??
      VerbosePlanInfo(
        unchanged: const [],
        differences: const {},
      );

  /// Get summary of the plan
  String get summary {
    final creates =
        operations.where((op) => op.type == OperationType.create).length;
    final updates =
        operations.where((op) => op.type == OperationType.update).length;
    final deletes =
        operations.where((op) => op.type == OperationType.delete).length;

    return '''
Plan Summary:
  Create: $creates
  Update: $updates
  Delete: $deletes
  Total: ${operations.length}
''';
  }

  Map<String, dynamic> toJson() {
    return {
      'operations': operations
          .map(
            (op) => {
              'type': op.type.name,
              'resourceId': op.resource?.id ?? op.currentState?.resourceId,
              'resourceType': op.resource?.runtimeType ??
                  op.currentState?.resource.runtimeType,
              'resourceClass':
                  op.resource?.runtimeType ?? op.currentState?.runtimeType,
            },
          )
          .toList(),
      'metadata': metadata,
    };
  }
}

/// Planner that creates plans from desired and actual states
class Planner {
  Plan createPlan({
    required State desired,
    required State actual,
    bool includeVerboseInfo = false,
  }) {
    final operations = <Operation>[];
    final unchanged = <String>[];
    final differences = <String, List<PropertyDifference>>{};

    // Build dependency graph from desired resources
    final dependencyGraph = DependencyGraph();
    for (final resourceState in desired.resources.values) {
      dependencyGraph.addResource(resourceState.resource);
    }

    // Validate that all dependencies are present
    // This catches configuration errors where a resource depends on
    // another resource that isn't in the desired resources.
    dependencyGraph.validateDependencies();

    // Note: With Resource references, circular dependencies are impossible
    // at compile time. If a cycle exists (e.g., from corrupted state),
    // topologicalSort() will throw an error when we order operations.

    // Find resources to create
    for (final resourceId in desired.resources.keys) {
      if (!actual.resources.containsKey(resourceId)) {
        final resource = desired.resources[resourceId]!.resource;
        
        // Skip read-only resources - they cannot be created, only read
        if (resource is ReadOnlyResource) {
          continue;
        }
        
        final resourceToAdd = _tryBuildDependentResource(resource, actual);
        operations.add(Operation.create(resource: resourceToAdd));
      }
    }

    // Find resources to update
    for (final resourceId in desired.resources.keys) {
      if (actual.resources.containsKey(resourceId)) {
        final desiredResource = desired.resources[resourceId]!.resource;
        final currentState = actual.resources[resourceId]!;

        // Skip read-only resources - they cannot be updated, only read
        if (desiredResource is ReadOnlyResource) {
          // Read-only resources are always considered unchanged (they're external)
          if (includeVerboseInfo) {
            unchanged.add(resourceId);
          }
          continue;
        }

        // For DependentResource, try to build it if dependencies exist
        final resourceToCompare = _tryBuildDependentResourceForComparison(
          desiredResource,
          actual,
          currentState,
        );

        // If resourceToCompare is null, dependencies don't exist yet
        // Skip update detection - this resource will be created in a later cycle
        if (resourceToCompare == null) {
          continue;
        }

        if (_hasChanges(resourceToCompare, currentState)) {
          operations.add(
            Operation.update(
              currentState: currentState,
              resource: desiredResource, // Use original for operation
            ),
          );

          // Collect differences for verbose output
          if (includeVerboseInfo) {
            differences[resourceId] =
                _getDifferences(resourceToCompare, currentState);
          }
        } else if (includeVerboseInfo) {
          // Resource is unchanged
          unchanged.add(resourceId);
        }
      }
    }

    // Find resources to delete
    for (final resourceId in actual.resources.keys) {
      if (!desired.resources.containsKey(resourceId)) {
        final currentState = actual.resources[resourceId]!;
        
        // Skip read-only resources - they cannot be deleted, only read
        if (currentState.resource is ReadOnlyResource) {
          continue;
        }
        
        operations.add(
          Operation.delete(
            currentState: currentState,
          ),
        );
      }
    }

    // Order operations based on dependencies
    final orderedOperations = _orderOperations(operations, dependencyGraph);

    // Build verbose info if requested
    VerbosePlanInfo? verboseInfo;
    if (includeVerboseInfo) {
      verboseInfo = VerbosePlanInfo(
        unchanged: unchanged,
        differences: differences,
      );
    }

    return Plan(
      operations: orderedOperations,
      verboseInfo: verboseInfo,
    );
  }

  /// Try to build a DependentResource if dependencies are available
  ///
  /// Returns the built resource if successful, or the original resource if:
  /// - It's not a DependentResource
  /// - Dependencies don't exist yet
  /// - Building fails
  Resource _tryBuildDependentResource(
    Resource resource,
    State actual,
  ) {
    if (resource is! DependentResource) {
      return resource;
    }

    // Check if all dependencies exist in actual state
    final canBuild = resource.dependencies.every(
      (dep) => actual.resources.containsKey(dep.id),
    );

    if (!canBuild) {
      // Dependencies don't exist yet - return original resource
      // It will be built during execution when dependencies are available
      return resource;
    }

    // Try to build it now for better planning accuracy
    try {
      final dependencyStates = <ResourceState>[];
      for (final dep in resource.dependencies) {
        dependencyStates.add(actual.resources[dep.id]!);
      }
      return resource.build(dependencyStates);
    } catch (e) {
      // If building fails, still return the original DependentResource
      // It will be built during execution
      return resource;
    }
  }

  /// Try to build a DependentResource for comparison during update detection
  ///
  /// Returns the built resource if successful, or null if dependencies don't exist.
  /// For non-DependentResources, returns the original resource.
  Resource? _tryBuildDependentResourceForComparison(
    Resource desiredResource,
    State actual,
    ResourceState currentState,
  ) {
    if (desiredResource is! DependentResource) {
      return desiredResource;
    }

    // Check if all dependencies exist in actual state
    final canBuild = desiredResource.dependencies.every(
      (dep) => actual.resources.containsKey(dep.id),
    );

    if (!canBuild) {
      // Dependencies don't exist - can't build, so skip update detection
      // This resource will be created in a later cycle
      return null;
    }

    // Try to build it for comparison
    try {
      final dependencyStates = <ResourceState>[];
      for (final dep in desiredResource.dependencies) {
        dependencyStates.add(actual.resources[dep.id]!);
      }
      return desiredResource.build(dependencyStates);
    } catch (e) {
      // If building fails, use the actual state's resource for comparison
      // This handles the case where the resource was already built
      return currentState.resource;
    }
  }

  /// Order operations based on dependency graph
  List<Operation> _orderOperations(
    List<Operation> operations,
    DependencyGraph dependencyGraph,
  ) {
    // Separate operations by type
    final creates =
        operations.where((op) => op.type == OperationType.create).toList();
    final updates =
        operations.where((op) => op.type == OperationType.update).toList();
    final deletes =
        operations.where((op) => op.type == OperationType.delete).toList();

    // Order creates: dependencies first (topological sort)
    final createOrder = dependencyGraph.topologicalSort();
    creates.sort((a, b) {
      final aIndex = createOrder.indexOf(a.resource?.id ?? '');
      final bIndex = createOrder.indexOf(b.resource?.id ?? '');
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;
      return aIndex.compareTo(bIndex);
    });

    // Order updates: dependencies first (topological sort)
    updates.sort((a, b) {
      final aIndex = createOrder.indexOf(a.resource?.id ?? '');
      final bIndex = createOrder.indexOf(b.resource?.id ?? '');
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;
      return aIndex.compareTo(bIndex);
    });

    // Order deletes: dependents first (reverse topological sort)
    final deleteOrder = dependencyGraph.reverseTopologicalSort();
    deletes.sort((a, b) {
      final aId = a.currentState?.resourceId ?? '';
      final bId = b.currentState?.resourceId ?? '';
      final aIndex = deleteOrder.indexOf(aId);
      final bIndex = deleteOrder.indexOf(bId);
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;
      return aIndex.compareTo(bIndex);
    });

    // Combine: creates first, then updates, then deletes
    return [...creates, ...updates, ...deletes];
  }

  bool _hasChanges(Resource desired, ResourceState current) {
    // Compare the desired resource with the actual resource in the state
    // Since ResourceState now contains a Resource with actual values,
    // we can directly compare the two Resource instances
    final desiredJson = ResourceSerialization.toJson(desired);
    final currentJson = ResourceSerialization.toJson(current.resource);

    // Properties are at the top level, excluding metadata fields
    // Metadata fields: '.type', 'id', 'dependencies'
    const metadataFields = {'.type', 'id', 'dependencies'};

    // Compare all properties from the desired resource
    const equality = DeepCollectionEquality();
    for (final key in desiredJson.keys) {
      // Skip metadata fields
      if (metadataFields.contains(key)) continue;

      final desiredValue = desiredJson[key];
      final currentValue = currentJson[key];

      if (!equality.equals(desiredValue, currentValue)) {
        // Found a difference - changes needed
        return true;
      }
    }

    // All desired properties match - no changes needed
    return false;
  }

  /// Get detailed differences between desired resource and current state
  ///
  /// Compares the desired resource with the actual resource in the state.
  List<PropertyDifference> _getDifferences(
    Resource desired,
    ResourceState current,
  ) {
    final differences = <PropertyDifference>[];

    // Get properties from both resources
    final desiredJson = ResourceSerialization.toJson(desired);
    final currentJson = ResourceSerialization.toJson(current.resource);

    // Properties are at the top level, excluding metadata fields
    // Metadata fields: '.type', 'id', 'dependencies'
    const metadataFields = {'.type', 'id', 'dependencies'};

    // Compare all properties from the desired resource
    const equality = DeepCollectionEquality();
    for (final key in desiredJson.keys) {
      // Skip metadata fields
      if (metadataFields.contains(key)) continue;

      final desiredValue = desiredJson[key];
      final currentValue = currentJson[key];

      // Check if values are different
      if (!equality.equals(desiredValue, currentValue)) {
        differences.add(
          PropertyDifference(
            field: key,
            current: currentValue,
            desired: desiredValue,
          ),
        );
      }
    }

    return differences;
  }
}
