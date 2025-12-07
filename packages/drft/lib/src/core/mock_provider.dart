/// Mock provider for testing and examples
///
/// This provider persists state to a file, making it useful for examples
/// and testing scenarios where you want state to persist across runs.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import '../utils/exceptions.dart';
import '../utils/package_root.dart';
import 'provider.dart';
import 'resource.dart';
import 'resource_serialization.dart';
import 'resource_state_serialization.dart';
import 'state.dart';

/// Mock provider for testing and examples
///
/// This provider persists state to a file, making it useful for examples
/// and testing scenarios where you want state to persist across runs.
class MockProvider extends Provider {
  final Map<String, ResourceState> _resources = {};
  final String? _storagePath;
  bool _initialized = false;
  bool _loaded = false;

  /// Create a MockProvider
  ///
  /// [storagePath] is optional. If provided, the provider will persist
  /// its state to this file. If not provided, state is only in memory.
  ///
  /// Example:
  /// ```dart
  /// MockProvider(storagePath: '.drft/mock-provider-state.json')
  /// ```
  MockProvider({String? storagePath})
      : _storagePath = storagePath,
        super(
          name: 'mock',
          version: '1.0.0',
        );

  @override
  Future<void> configure(Map<String, dynamic> config) async {}

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (_storagePath != null && !_loaded) {
      await _loadState();
      _loaded = true;
    }
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    if (!_initialized) return;
    if (_storagePath != null) {
      await _saveState();
    }
    _initialized = false;
  }

  @override
  Future<ResourceState> createResource(Resource resource) async {
    final resourceType = '$resource.runtimeType';

    // Create typed state if we know the type
    // For MockProvider, we'll import the example state classes
    // In a real provider, you'd import the typed state classes from the provider package
    ResourceState state;

    if (resourceType.contains('AppStoreBundleId')) {
      // Simulate App Store assigning a bundle ID (read-only property)
      final bundleIdValue = 'com.example.${resource.id.split('.').last}';

      // Create state with the resource (actual values same as desired for mock)
      // plus the read-only bundleId property
      state = _createAppStoreBundleIdState(
        resource: resource,
        bundleId: bundleIdValue,
      );
    } else if (resourceType.contains('ProvisioningProfile')) {
      // ProvisioningProfileState has no read-only properties
      // All properties are in the Resource
      state = _createProvisioningProfileState(
        resource: resource,
      );
    } else {
      // Generic ResourceState for other resource types
      // The resource contains all the actual values
      state = ResourceState(
        resource: resource,
      );
    }

    _resources[resource.id] = state;
    await _saveState();
    return state;
  }

  // Helper methods to create typed states
  // These would normally be in the provider package, but for MockProvider
  // we create them dynamically using reflection
  ResourceState _createAppStoreBundleIdState({
    required Resource resource,
    required String bundleId,
  }) {
    // Use reflection to create the typed state
    // This is a workaround - in a real provider, you'd import the state class
    try {
      final libraries = currentMirrorSystem().libraries;
      for (final library in libraries.values) {
        for (final declaration in library.declarations.values) {
          if (declaration is ClassMirror) {
            final className = MirrorSystem.getName(declaration.simpleName);
            if (className == 'AppStoreBundleIdState') {
              // Found the class, create instance with resource and read-only property
              final instanceMirror = declaration.newInstance(
                const Symbol(''),
                [],
                {
                  const Symbol('resource'): resource,
                  const Symbol('bundleId'): bundleId,
                },
              );
              return instanceMirror.reflectee as ResourceState;
            }
          }
        }
      }
    } catch (e) {
      // Fallback to generic ResourceState if reflection fails
    }

    // Fallback: create generic ResourceState
    return ResourceState(
      resource: resource,
    );
  }

  ResourceState _createProvisioningProfileState({
    required Resource resource,
  }) {
    try {
      final libraries = currentMirrorSystem().libraries;
      for (final library in libraries.values) {
        for (final declaration in library.declarations.values) {
          if (declaration is ClassMirror) {
            final className = MirrorSystem.getName(declaration.simpleName);
            if (className == 'ProvisioningProfileState') {
              final instanceMirror = declaration.newInstance(
                const Symbol(''),
                [],
                {
                  const Symbol('resource'): resource,
                },
              );
              return instanceMirror.reflectee as ResourceState;
            }
          }
        }
      }
    } catch (e) {
      // Fallback to generic ResourceState if reflection fails
    }

    return ResourceState(
      resource: resource,
    );
  }

  @override
  Future<ResourceState> readResource(Resource resource) async {
    final state = _resources[resource.id];
    if (state == null) {
      throw ResourceNotFoundException(resource.id);
    }
    return state;
  }

  @override
  Future<ResourceState> updateResource(
    ResourceState current,
    Resource desired,
  ) async {
    // For update, preserve the state type if it's a typed state
    final resourceType = '$desired.runtimeType';

    ResourceState state;

    // Check if current state is a typed state (has read-only properties)
    // Typed states have properties at the top level (not under 'properties' key)
    final currentJson = ResourceStateSerialization.toJson(current);
    // Metadata fields that don't indicate typed properties
    const metadataFields = {'.type', 'resource'};
    final hasTypedProperties = currentJson.keys
            .where((key) => !metadataFields.contains(key))
            .isNotEmpty &&
        current.runtimeType != ResourceState;

    if (hasTypedProperties) {
      // Preserve the typed state - create a copy with updated resource
      // This preserves read-only properties (like bundleId for AppStoreBundleIdState)
      state = ResourceStateSerialization.copyWithResource(
        current,
        desired,
        (id) {
          final resource = _resources[id]?.resource;
          if (resource == null) {
            throw StateError('Dependency "$id" not found in MockProvider');
          }
          return resource;
        },
      );
    } else if (resourceType.contains('AppStoreBundleId')) {
      // Recreate typed state for AppStoreBundleId
      // Extract bundleId from current state (read-only property)
      // bundleId is at the top level of the JSON, not under 'properties'
      final bundleIdValue = currentJson['bundleId'] as String? ??
          'com.example.${desired.id.split('.').last}';
      state = _createAppStoreBundleIdState(
        resource: desired,
        bundleId: bundleIdValue,
      );
    } else if (resourceType.contains('ProvisioningProfile')) {
      // ProvisioningProfileState has no read-only properties
      state = _createProvisioningProfileState(
        resource: desired,
      );
    } else {
      // Generic ResourceState - resource contains all actual values
      state = ResourceState(
        resource: desired,
      );
    }

    _resources[desired.id] = state;
    await _saveState();
    return state;
  }

  @override
  Future<void> deleteResource(ResourceState state) async {
    _resources.remove(state.resourceId);
    await _saveState();
  }

  @override
  bool canHandle(Resource resource) => true;

  /// Load state from file
  Future<void> _loadState() async {
    if (_storagePath == null) return;

    try {
      // Resolve path relative to package root
      final resolvedPath =
          await resolvePathRelativeToPackageRoot(_storagePath!);
      final file = File(resolvedPath);
      if (!await file.exists()) {
        // No existing state, start fresh
        return;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      _resources.clear();
      final resourcesJson = json['resources'] as Map<String, dynamic>? ?? {};

      // First pass: deserialize all resources without dependencies
      // This ensures all resources are in the map before we try to look them up
      // Temporarily remove dependencies from JSON to avoid reconstruction in first pass
      for (final entry in resourcesJson.entries) {
        final resourceStateJson =
            Map<String, dynamic>.from(entry.value as Map<String, dynamic>);
        final resourceJson =
            resourceStateJson['resource'] as Map<String, dynamic>?;

        // Temporarily remove dependencies to avoid reconstruction in first pass
        final dependencyIds =
            resourceJson?.remove('dependencies') as List<dynamic>?;

        // Deserialize without dependencies (they'll be reconstructed in second pass)
        _resources[entry.key] = ResourceStateSerialization.fromJson(
          resourceStateJson,
          (id) =>
              throw StateError('Dependency "$id" not found during first pass'),
        );

        // Restore dependencies in the original JSON for second pass
        if (dependencyIds != null && resourceJson != null) {
          resourceJson['dependencies'] = dependencyIds;
        }
      }

      // Second pass: reconstruct dependencies using getDependency
      for (final entry in resourcesJson.entries) {
        final resourceState = _resources[entry.key]!;
        final resourceStateJson = entry.value as Map<String, dynamic>;
        final resourceJson =
            resourceStateJson['resource'] as Map<String, dynamic>?;

        if (resourceJson != null) {
          // Check if there are dependencies to reconstruct
          final dependencyIds = (resourceJson['dependencies'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              <String>[];

          if (dependencyIds.isNotEmpty) {
            // Deserialize resource again with getDependency to reconstruct dependencies
            Resource<ResourceState> getDependency(String id) {
              final resource = _resources[id]?.resource;
              if (resource == null) {
                throw StateError(
                  'Dependency "$id" not found in MockProvider state',
                );
              }
              return resource;
            }

            final resource = ResourceSerialization.fromJson(
              resourceJson,
              getDependency,
            );

            // Update the state with the reconstructed resource
            _resources[entry.key] = ResourceStateSerialization.copyWithResource(
              resourceState,
              resource,
              getDependency,
            );
          }
        }
      }
    } catch (e) {
      // If loading fails, start with empty state
      // This allows the provider to work even if the file is corrupted
      _resources.clear();
    }
  }

  /// Save state to file
  Future<void> _saveState() async {
    if (_storagePath == null) return;

    try {
      // Resolve path relative to package root
      final resolvedPath =
          await resolvePathRelativeToPackageRoot(_storagePath!);
      final file = File(resolvedPath);
      final directory = file.parent;

      // Ensure directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Convert resources to JSON
      final resourcesJson = <String, dynamic>{};
      for (final entry in _resources.entries) {
        resourcesJson[entry.key] =
            ResourceStateSerialization.toJson(entry.value);
      }

      final json = {
        'version': '1.0',
        'provider': 'mock',
        'resources': resourcesJson,
      };

      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(json));
    } catch (e) {
      // Log error but don't throw - persistence is best effort
      // In a real provider, you might want to log this
    }
  }
}
