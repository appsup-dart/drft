/// Internal serialization utilities for resource states
///
/// This file contains implementation details for serializing and deserializing
/// resource states. These are not part of the public API.
library;

import 'object_serialization.dart';
import 'resource.dart';
import 'resource_serialization.dart';
import 'state.dart';

/// Internal utility for resource state serialization
class ResourceStateSerialization {
  /// ObjectSerialization instance for this serializer
  static final ObjectSerialization _objectSerialization = ObjectSerialization();

  /// Convert resource state to JSON for serialization
  ///
  /// Structure:
  /// ```json
  /// {
  ///   ".type": "package_name.ClassName",
  ///   "resource": { ... },  // Serialized Resource
  ///   "property1": "value1",
  ///   ...
  /// }
  /// ```
  ///
  /// The `resource` field is serialized using ResourceSerialization.
  static Map<String, dynamic> toJson(ResourceState state) {
    // Use generic serialization, but handle resource field specially
    final json = _objectSerialization.toJson(
      state,
      fieldFilter: (fieldName) {
        // Skip resource field - we'll handle it specially
        if (fieldName == 'resource') return false;
        // Skip computed properties (resourceId, resourceType)
        if (fieldName == 'resourceId' || fieldName == 'resourceType') {
          return false;
        }
        return true;
      },
    );

    // Serialize the resource using ResourceSerialization
    final resourceJson = ResourceSerialization.toJson(state.resource);
    json['resource'] = resourceJson;

    return json;
  }

  /// Deserialize a resource state from JSON
  ///
  /// The JSON structure should match the format produced by [toJson].
  ///
  /// [getDependency] is a required function that takes a resource ID and returns
  /// the corresponding Resource. It must throw an exception if the dependency
  /// is not found. It will be passed to ResourceSerialization to reconstruct
  /// dependencies from IDs.
  static ResourceState fromJson(
    Map<String, dynamic> json,
    Resource Function(String id) getDependency,
  ) {
    // Try to deserialize the state
    // If the class is not found, fall back to basic ResourceState
    try {
      return _objectSerialization.fromJson<ResourceState>(
        json,
        fieldMapper: (fieldName, value) {
          if (fieldName == 'resource') {
            return ResourceSerialization.fromJson(
              value as Map<String, dynamic>,
              getDependency,
            );
          }
          return value;
        },
      );
    } on ArgumentError catch (e) {
      // If class not found, fall back to basic ResourceState
      if (e.message.contains('Could not find class')) {
        // Extract resource from JSON
        final resourceJson = json['resource'] as Map<String, dynamic>?;
        if (resourceJson != null) {
          final resource = ResourceSerialization.fromJson(
            resourceJson,
            getDependency,
          );
          return ResourceState(resource: resource);
        }
        throw ArgumentError('Missing "resource" field in JSON');
      }
      rethrow;
    }
  }

  /// Create a copy of a ResourceState with a new resource value
  ///
  /// This preserves all read-only properties of the original state but updates the resource.
  /// Works with both base ResourceState and typed subclasses.
  ///
  /// [getDependency] is a required function that takes a resource ID and returns
  /// the corresponding Resource. It must throw an exception if the dependency
  /// is not found. It will be used to reconstruct dependencies.
  static ResourceState copyWithResource(
    ResourceState state,
    Resource resource,
    Resource Function(String id) getDependency,
  ) {
    // Serialize the state to get read-only properties (if any)
    final json = toJson(state);

    // Update the resource
    json['resource'] = ResourceSerialization.toJson(resource);

    // Deserialize with updated resource
    return fromJson(json, getDependency);
  }
}
