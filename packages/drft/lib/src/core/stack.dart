/// DRFT Stack - Top-level container for infrastructure
library;

import 'resource.dart';
import 'provider.dart';
import 'state.dart';
import 'plan.dart';
import 'executor.dart';
import '../utils/exceptions.dart';

/// A stack represents a collection of resources and providers
/// that define a complete infrastructure configuration.
class DrftStack {
  /// Name of the stack
  final String name;

  /// List of providers used by resources in this stack
  final List<Provider<Resource>> providers;

  /// List of resources defined in this stack
  final List<Resource> resources;

  /// State manager for tracking infrastructure state
  final StateManager stateManager;

  /// Executor for applying changes
  final Executor executor;

  DrftStack({
    required this.name,
    required this.providers,
    required this.resources,
    StateManager? stateManager,
    Executor? executor,
  })  : stateManager = stateManager ?? StateManager(),
        executor = executor ?? Executor(providers: providers);

  /// Create a plan showing what changes would be made
  Future<Plan> plan({bool includeVerboseInfo = false}) async {
    final desiredState = State.fromResources(resources, stackName: name);
    final actualState = await stateManager.load();

    final planner = Planner();
    return planner.createPlan(
      desired: desiredState,
      actual: actualState,
      includeVerboseInfo: includeVerboseInfo,
    );
  }

  /// Apply the planned changes
  Future<ApplyResult> apply(Plan plan) async {
    // Get desired state to preserve stack name
    final desiredState = State.fromResources(resources, stackName: name);
    return await executor.execute(
      plan,
      stateManager,
      desiredState: desiredState,
    );
  }

  /// Refresh state from actual infrastructure
  ///
  /// Reads the current state of all resources defined in the stack from the
  /// actual infrastructure (via providers) and updates the state file.
  /// This creates a complete new state based on what actually exists.
  ///
  /// This is useful when:
  /// - Resources have been modified outside of DRFT
  /// - State file has become out of sync with reality
  /// - You want to verify current infrastructure state
  /// - You want to detect drift (resources that exist but aren't in stack)
  ///
  /// Returns the refreshed state.
  Future<State> refresh() async {
    // Lock state file to prevent concurrent modifications
    await stateManager.lock();

    try {
      final refreshedResources = <String, ResourceState>{};

      // Initialize all providers
      for (final provider in providers) {
        await provider.initialize();
      }

      try {
        // Refresh each resource from the stack definition (desired resources)
        // This reads the actual state from infrastructure for all resources
        // we expect to exist, creating a complete new state
        for (final resource in resources) {
          // Find the provider that can handle this resource
          Provider<Resource>? provider;

          // Find provider that can handle this resource
          for (final p in providers) {
            if (p.canHandle(resource)) {
              provider = p;
              break;
            }
          }

          if (provider == null) {
            // If no provider found, this is an error condition
            throw DrftException(
              'No provider found for resource ${resource.id} '
              '(${resource.runtimeType}). '
              'Make sure a provider that can handle this resource type is '
              'included in the stack providers.',
            );
          }

          // Read the current state from the provider
          // This calls the provider's readResource method to get the
          // actual current state from the infrastructure
          try {
            final refreshedState = await provider.readResource(resource);
            refreshedResources[resource.id] = refreshedState;
          } on ResourceNotFoundException {
            // Resource doesn't exist in infrastructure - skip it
            // This is expected if the resource hasn't been created yet
            // or was deleted externally. It won't be included in the
            // refreshed state, which is correct since it doesn't exist.
            continue;
          }
          // Other exceptions (network errors, provider errors, etc.)
          // should propagate to the user - they indicate real problems
        }

        // Create refreshed state with resources from actual infrastructure
        // This is a completely new state based on what actually exists
        final refreshedState = State(
          stackName: name,
          resources: refreshedResources,
        );

        // Save the refreshed state
        await stateManager.save(refreshedState);

        return refreshedState;
      } finally {
        // Dispose all providers
        for (final provider in providers) {
          await provider.dispose();
        }
      }
    } finally {
      // Unlock state file
      await stateManager.unlock();
    }
  }

  /// Destroy all resources in this stack
  ///
  /// Creates a plan to delete all resources in the current state and applies it.
  /// Resources are deleted in reverse dependency order (dependents before dependencies).
  ///
  /// Returns the result of the destroy operation.
  Future<ApplyResult> destroy() async {
    // Load current state
    final currentState = await stateManager.load();

    if (currentState.resources.isEmpty) {
      // No resources to destroy
      return ApplyResult(
        success: true,
        operations: [],
        summary: 'Destroy Summary:\n  No resources to destroy\n',
      );
    }

    // Create destroy plan (empty desired state = delete everything)
    final emptyState = State.empty(stackName: name);
    final planner = Planner();
    final plan = planner.createPlan(
      desired: emptyState,
      actual: currentState,
    );

    // Apply destroy plan
    return await executor.execute(plan, stateManager, desiredState: emptyState);
  }
}
