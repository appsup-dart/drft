/// Resource - Base class for all infrastructure resources
library;

import 'package:meta/meta.dart';

import 'state.dart';

/// Base class for all infrastructure resources.
///
/// Resources are immutable and represent a desired state
/// of a piece of infrastructure.
///
/// [StateType] is the type of ResourceState that this resource produces.
/// This allows type-safe access to state properties.
///
/// **Serialization Requirements:**
/// Resources are automatically serialized to JSON for state persistence.
/// All public fields must be JSON-serializable types:
/// - `String`, `num`, `bool`, `null`
/// - `List` (of serializable types)
/// - `Map` (with string keys and serializable values)
/// - Other `Resource` instances (recursively serialized)
///
/// **Non-serializable types** (functions, closures, complex objects) will be
/// converted to strings during serialization, but **cannot be deserialized**.
/// This will cause a `TypeError` if the field is required. Make such fields
/// optional if they're not needed for state persistence.
///
/// Example:
/// ```dart
/// class ProvisioningProfileState extends ResourceState {
///   final String bundleId; // Read-only property from provider
///
///   ProvisioningProfileState({
///     required super.resource,
///     required this.bundleId,
///   });
/// }
///
/// class ProvisioningProfile extends Resource<ProvisioningProfileState> {
///   final String bundleId;
///   final String type;
///
///   const ProvisioningProfile({
///     required String id,
///     required this.bundleId,
///     required this.type,
///     List<Resource> dependencies = const [],
///   }) : super(
///           id: id,
///           dependencies: dependencies,
///         );
/// }
/// ```
@immutable
abstract class Resource<StateType extends ResourceState> {
  /// Unique identifier for this resource
  final String id;

  /// Explicit dependencies on other resources
  /// Using Resource references instead of IDs provides type safety
  /// and prevents dependency cycles at compile time.
  final List<Resource> dependencies;

  const Resource({
    required this.id,
    this.dependencies = const [],
  });
}
