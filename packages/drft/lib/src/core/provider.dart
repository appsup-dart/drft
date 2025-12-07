/// Provider - Interface for managing resources on different platforms
library;

import 'resource.dart';
import 'state.dart';

/// Base interface for all providers
///
/// [ResourceType] specifies the type of resources this provider can handle.
/// By default, it accepts any Resource, but can be constrained to a specific
/// type or base class for type safety.
///
/// Example:
/// ```dart
/// // Provider for a specific resource type
/// class FirebaseAppProvider extends Provider<FirebaseApp> {
///   // Methods receive FirebaseApp directly, no casting needed
/// }
///
/// // Provider for multiple related resource types via base class
/// class FirebaseProvider extends Provider<FirebaseResource> {
///   // Can handle FirebaseApp, FirebaseProject, etc.
/// }
/// ```
abstract class Provider<ResourceType extends Resource> {
  /// Name of the provider (e.g., 'aws', 'firebase', 'kubernetes')
  final String name;

  /// Version of the provider
  final String version;

  /// Create a provider with the given name and version
  Provider({
    required this.name,
    required this.version,
  });

  /// Configure the provider
  Future<void> configure(Map<String, dynamic> config);

  /// Create a resource
  ///
  /// The [resource] parameter is typed as [ResourceType], so no casting
  /// is needed in the implementation.
  Future<ResourceState> createResource(ResourceType resource);

  /// Read the current state of a resource
  ///
  /// The [resource] parameter is typed as [ResourceType], so no casting
  /// is needed in the implementation.
  Future<ResourceState> readResource(ResourceType resource);

  /// Update an existing resource
  ///
  /// The [desired] parameter is typed as [ResourceType], so no casting
  /// is needed in the implementation.
  Future<ResourceState> updateResource(
    ResourceState current,
    ResourceType desired,
  );

  /// Delete a resource
  Future<void> deleteResource(ResourceState state);

  /// Check if this provider can handle a resource type
  ///
  /// Default implementation checks if the resource is an instance of
  /// [ResourceType]. Override this method for custom logic.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool canHandle(Resource resource) {
  ///   if (resource is! MyResource) return false;
  ///   // Additional custom logic
  ///   return resource.shouldBeHandledByThisProvider;
  /// }
  /// ```
  bool canHandle(Resource resource) {
    return resource is ResourceType;
  }

  /// Initialize the provider
  Future<void> initialize();

  /// Clean up the provider
  Future<void> dispose();
}
