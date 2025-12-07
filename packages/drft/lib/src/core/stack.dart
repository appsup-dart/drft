/// DRFT Stack - Top-level container for infrastructure
library;

import 'resource.dart';
import 'provider.dart';
import 'state.dart';
import 'plan.dart';
import 'executor.dart';

/// A stack represents a collection of resources and providers
/// that define a complete infrastructure configuration.
class DrftStack {
  /// Name of the stack
  final String name;

  /// List of providers used by resources in this stack
  final List<Provider> providers;

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
  /// Reads the current state of all resources from the actual infrastructure
  /// (via providers) and updates the state file. This is useful when:
  /// - Resources have been modified outside of DRFT
  /// - State file has become out of sync with reality
  /// - You want to verify current infrastructure state
  ///
  /// Returns the refreshed state.
  Future<State> refresh() async {
    // Lock state file to prevent concurrent modifications
    await stateManager.lock();

    try {
      // Load current state to get list of resources to refresh
      final currentState = await stateManager.load();
      final refreshedResources = <String, ResourceState>{};

      // Initialize all providers
      for (final provider in providers) {
        await provider.initialize();
      }

      try {
        // Refresh each resource from the actual infrastructure
        for (final resourceState in currentState.resources.values) {
          try {
            // Find the provider that can handle this resource
            Provider? provider;

            // Find provider that can handle this resource
            for (final p in providers) {
              if (p.canHandle(resourceState.resource)) {
                provider = p;
                break;
              }
            }

            if (provider == null) {
              // If no provider found, keep the existing state
              refreshedResources[resourceState.resourceId] = resourceState;
              continue;
            }

            // Read the current state from the provider
            final refreshedState = await provider.readResource(
              resourceState.resource,
            );

            refreshedResources[resourceState.resourceId] = refreshedState;
          } catch (e) {
            // If reading fails (e.g., resource was deleted externally),
            // we could either:
            // 1. Remove it from state (drift detection)
            // 2. Keep the old state (conservative approach)
            // For now, we'll keep the old state to be conservative
            refreshedResources[resourceState.resourceId] = resourceState;
          }
        }

        // Create refreshed state
        final refreshedState = State(
          version: currentState.version,
          stackName: currentState.stackName,
          resources: refreshedResources,
          metadata: currentState.metadata,
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
