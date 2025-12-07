/// Executor - Execute plans to apply infrastructure changes
library;

import '../utils/exceptions.dart';
import 'dependent_resource.dart';
import 'plan.dart';
import 'provider.dart';
import 'resource.dart';
import 'resource_state_serialization.dart';
import 'state.dart';

/// Result of applying an operation
class OperationResult {
  final Operation operation;
  final ResourceState? newState;
  final bool success;
  final String? error;
  final StackTrace? stackTrace;

  OperationResult({
    required this.operation,
    this.newState,
    this.success = true,
    this.error,
    this.stackTrace,
  });

  factory OperationResult.success({
    required Operation operation,
    ResourceState? newState,
  }) {
    return OperationResult(
      operation: operation,
      newState: newState,
      success: true,
    );
  }

  factory OperationResult.failure({
    required Operation operation,
    required String error,
    StackTrace? stackTrace,
  }) {
    return OperationResult(
      operation: operation,
      success: false,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Result of applying a plan
class ApplyResult {
  final bool success;
  final List<OperationResult> operations;
  final String summary;

  ApplyResult({
    required this.success,
    required this.operations,
    required this.summary,
  });
}

/// Executes plans to apply infrastructure changes
class Executor {
  final List<Provider> providers;

  Executor({
    required this.providers,
  });

  /// Execute a plan
  Future<ApplyResult> execute(
    Plan plan,
    StateManager stateManager, {
    State? desiredState,
  }) async {
    await stateManager.lock();

    try {
      final results = <OperationResult>[];
      final createdStates = <String, ResourceState>{};

      // Load current state to get dependencies from previous executions
      final currentState = await stateManager.load();

      // Read read-only resources that are in desired state but not in actual state
      // This verifies they exist externally before other operations depend on them
      final readOnlyResourceStates = <String, ResourceState>{};
      if (desiredState != null) {
        for (final resourceId in desiredState.resources.keys) {
          if (!currentState.resources.containsKey(resourceId)) {
            final resource = desiredState.resources[resourceId]!.resource;
            if (resource is ReadOnlyResource) {
              try {
                // Find provider for this read-only resource
                final provider = _findProviderForResource(resource);
                // Read the read-only resource to verify it exists
                final readOnlyResourceState =
                    await provider.readResource(resource);
                // Store for later use and state persistence
                readOnlyResourceStates[resourceId] = readOnlyResourceState;
                currentState.resources[resourceId] = readOnlyResourceState;
              } on ResourceNotFoundException {
                throw DrftException(
                  'Read-only resource ${resource.id} (${resource.runtimeType}) not found. '
                  'Read-only resources must exist externally before they can be used. '
                  'Please create ${resource.runtimeType} with ${resource.id} '
                  'through the appropriate external system.',
                );
              }
            }
          }
        }
      }

      final availableStates = <String, ResourceState>{
        ...currentState.resources,
        ...createdStates,
      };

      for (final operation in plan.operations) {
        try {
          final result = await _executeOperationWithDependentResource(
            operation,
            availableStates,
          );

          results.add(result);

          // Track created states for future DependentResource dependencies
          if (result.success &&
              result.newState != null &&
              operation.type == OperationType.create) {
            createdStates[result.newState!.resourceId] = result.newState!;
            // Also update availableStates so subsequent operations can use it
            availableStates[result.newState!.resourceId] = result.newState!;
          }
        } on ProviderNotFoundException {
          // Re-throw ProviderNotFoundException - it should propagate to caller
          rethrow;
        } catch (e, stackTrace) {
          results.add(
            OperationResult.failure(
              operation: operation,
              error: e.toString(),
              stackTrace: stackTrace,
            ),
          );
          // Error handling strategy: Continue executing remaining operations
          // even if some fail. This allows partial success and provides a
          // complete report of all failures at the end. The overall operation
          // is considered failed if any operation fails.
        }
      }

      // Build summary
      final successful = results.where((r) => r.success).length;
      final failed = results.where((r) => !r.success).length;
      final summary = '''
Apply Summary:
  Successful: $successful
  Failed: $failed
  Total: ${results.length}
''';

      // Save state if execution was successful
      if (failed == 0) {
        // Build updated state from successful operations
        // Always load current state to preserve existing resource states
        final baseState = await stateManager.load();
        final updatedResources =
            Map<String, ResourceState>.from(baseState.resources);

        // Include read-only resource states that were read during execution
        updatedResources.addAll(readOnlyResourceStates);

        for (final result in results) {
          if (result.success && result.newState != null) {
            // Always use the newState from the result - it contains the built resource
            // for DependentResources, not the wrapper
            updatedResources[result.newState!.resourceId] = result.newState!;
          } else if (result.success &&
              result.operation.type == OperationType.delete) {
            // Remove deleted resources from state
            final resourceId = result.operation.currentState?.resourceId;
            if (resourceId != null) {
              updatedResources.remove(resourceId);
            }
          }
        }

        final updatedState = State(
          version: baseState.version,
          stackName: desiredState?.stackName ?? baseState.stackName,
          resources: updatedResources,
          metadata: baseState.metadata,
        );
        await stateManager.save(updatedState);
      }

      return ApplyResult(
        success: failed == 0,
        operations: results,
        summary: summary,
      );
    } finally {
      await stateManager.unlock();
    }
  }

  /// Execute an operation, handling DependentResource if needed
  ///
  /// If the operation contains a DependentResource, it will be built from
  /// dependency states before execution. The result will reference the built
  /// resource, not the wrapper.
  Future<OperationResult> _executeOperationWithDependentResource(
    Operation operation,
    Map<String, ResourceState> createdStates,
  ) async {
    // Handle DependentResource: build it from dependency states
    Resource? resourceToExecute = operation.resource;

    if (resourceToExecute is DependentResource) {
      // Build the resource from dependency states
      // Convert map to list in the order of dependencies
      final dependencyStates = <ResourceState>[];
      for (final dep in resourceToExecute.dependencies) {
        if (!createdStates.containsKey(dep.id)) {
          throw DrftException(
            'Dependency ${dep.id} not found in created states. '
            'Make sure all dependencies are created before building this resource.',
          );
        }
        dependencyStates.add(createdStates[dep.id]!);
      }
      resourceToExecute = resourceToExecute.build(dependencyStates);
    }

    // Create a modified operation with the built resource if needed
    final operationToExecute = resourceToExecute != operation.resource
        ? Operation.create(resource: resourceToExecute!)
        : operation;

    Provider provider;
    try {
      provider = _findProvider(operationToExecute);
    } on ProviderNotFoundException {
      // Re-throw ProviderNotFoundException so it's not caught and converted to a failure
      rethrow;
    }
    final result = await _executeOperation(operationToExecute, provider);

    // If we built a DependentResource, update the result's state to use the built resource
    // This ensures we save the built resource, not the wrapper
    final wasDependentResource = operation.resource is DependentResource;
    if (wasDependentResource &&
        result.success &&
        result.newState != null &&
        resourceToExecute != null) {
      // Create a new state with the built resource (not the wrapper)
      // Note: getDependency should not be called since dependencies are already set in the resource
      // But we still need to provide it - it will throw if called (which shouldn't happen)
      final updatedState = ResourceStateSerialization.copyWithResource(
        result.newState!,
        resourceToExecute,
        (id) => throw StateError(
          'Unexpected dependency lookup for "$id" in Executor',
        ),
      );
      return OperationResult.success(
        operation: result.operation,
        newState: updatedState,
      );
    }

    return result;
  }

  Provider _findProvider(Operation operation) {
    final resource = operation.resource ?? operation.currentState?.resource;
    if (resource == null) {
      throw DrftException('Cannot find provider: no resource in operation');
    }

    return _findProviderForResource(resource);
  }

  Provider _findProviderForResource(Resource resource) {
    for (final provider in providers) {
      if (provider.canHandle(resource)) {
        return provider;
      }
    }

    throw ProviderNotFoundException('${resource.runtimeType}');
  }

  Future<OperationResult> _executeOperation(
    Operation operation,
    Provider provider,
  ) async {
    switch (operation.type) {
      case OperationType.create:
        if (operation.resource == null) {
          throw DrftException('Create operation requires a resource');
        }
        final state = await provider.createResource(operation.resource!);
        return OperationResult.success(
          operation: operation,
          newState: state,
        );

      case OperationType.update:
        if (operation.resource == null || operation.currentState == null) {
          throw DrftException(
            'Update operation requires resource and current state',
          );
        }
        final state = await provider.updateResource(
          operation.currentState!,
          operation.resource!,
        );
        return OperationResult.success(
          operation: operation,
          newState: state,
        );

      case OperationType.delete:
        if (operation.currentState == null) {
          throw DrftException('Delete operation requires current state');
        }
        await provider.deleteResource(operation.currentState!);
        return OperationResult.success(operation: operation);
    }
  }
}
