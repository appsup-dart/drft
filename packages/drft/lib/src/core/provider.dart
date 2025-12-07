/// Provider - Interface for managing resources on different platforms
library;

import 'resource.dart';
import 'state.dart';

/// Base interface for all providers
abstract class Provider {
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
  Future<ResourceState> createResource(Resource resource);

  /// Read the current state of a resource
  Future<ResourceState> readResource(Resource resource);

  /// Update an existing resource
  Future<ResourceState> updateResource(
    ResourceState current,
    Resource desired,
  );

  /// Delete a resource
  Future<void> deleteResource(ResourceState state);

  /// Check if this provider can handle a resource type
  bool canHandle(Resource resource);

  /// Initialize the provider
  Future<void> initialize();

  /// Clean up the provider
  Future<void> dispose();
}
