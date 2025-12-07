/// Internal serialization utilities for resources
///
/// This file contains implementation details for serializing and deserializing
/// resources. These are not part of the public API.
library;

import 'object_serialization.dart';
import 'resource.dart';

/// Internal utility for resource serialization
class ResourceSerialization {
  /// ObjectSerialization instance for this serializer
  static final ObjectSerialization _objectSerialization = ObjectSerialization();

  /// Convert resource to JSON for serialization
  ///
  /// Structure:
  /// ```json
  /// {
  ///   ".type": "package_name.ClassName",
  ///   "id": "...",
  ///   "dependencies": ["id1", "id2"],
  ///   "property1": "value1",
  ///   ...
  /// }
  /// ```
  ///
  /// Dependencies are serialized as IDs (not Resource objects) for JSON compatibility.
  static Map<String, dynamic> toJson(Resource resource) {
    // Use generic serialization, but handle dependencies specially
    final json = _objectSerialization.toJson(
      resource,
      fieldFilter: (fieldName) {
        // Include all fields except we'll handle dependencies specially
        return true;
      },
    );

    // Convert dependencies from Resource objects to IDs
    final dependencyIds = resource.dependencies.map((r) => r.id).toList();
    json['dependencies'] = dependencyIds;

    return json;
  }

  /// Deserialize a resource from JSON
  ///
  /// The JSON structure should match the format produced by [toJson].
  ///
  /// [getDependency] is a required function that takes a resource ID and returns
  /// the corresponding Resource. It must throw an exception if the dependency
  /// is not found. Dependencies will be reconstructed from the dependency IDs
  /// in the JSON using this function.
  static Resource fromJson(
    Map<String, dynamic> json,
    Resource Function(String id) getDependency,
  ) {
    // Use generic deserialization with fieldMapper to convert dependency IDs to Resources
    final resource = _objectSerialization.fromJson<Resource>(
      json,
      fieldMapper: (fieldName, value) {
        if (fieldName == 'dependencies') {
          assert(value is List);
          // Convert dependency IDs to Resource objects using getDependency
          // getDependency must throw if dependency is not found
          return (value as List).map((id) => getDependency(id)).toList();
        }
        return value;
      },
    );

    return resource;
  }
}
