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

/// Base class for read-only external resources (data sources)
///
/// Read-only resources represent external infrastructure that cannot be
/// created, updated, or deleted through DRFT. They are used to fetch
/// information from external systems that other resources depend on.
///
/// Examples:
/// - Firebase projects (must be created via Firebase Console)
/// - Existing cloud resources managed outside DRFT
/// - External APIs that provide reference data
///
/// Read-only resources:
/// - Are only read (to verify existence and get current state)
/// - Are never created, updated, or deleted in plans
/// - Can be used as dependencies by other resources
/// - Are refreshed during state refresh operations
///
/// Example:
/// ```dart
/// class FirebaseProject extends ReadOnlyResource<FirebaseProjectState> {
///   final String projectId;
///   final String displayName;
///
///   const FirebaseProject({
///     required String id,
///     required this.projectId,
///     required this.displayName,
///     List<Resource> dependencies = const [],
///   }) : super(
///           id: id,
///           dependencies: dependencies,
///         );
/// }
/// ```
///
/// **Alternative:** If your resource extends a base class and cannot extend
/// `ReadOnlyResource`, use the `ReadOnly` mixin instead (see below).
@immutable
abstract class ReadOnlyResource<StateType extends ResourceState>
    extends Resource<StateType> with ReadOnly {
  const ReadOnlyResource({
    required super.id,
    super.dependencies = const [],
  });
}

/// Mixin for marking resources as read-only
///
/// Use this mixin when a resource extends a base class (like `FirebaseResource`)
/// and cannot extend `ReadOnlyResource` directly.
///
/// Example:
/// ```dart
/// class FirebaseProject extends FirebaseResource<FirebaseProjectState>
///     with ReadOnly {
///   final String projectId;
///   final String displayName;
///
///   const FirebaseProject({
///     required String id,
///     required this.projectId,
///     required this.displayName,
///     List<Resource> dependencies = const [],
///   }) : super(
///           id: id,
///           dependencies: dependencies,
///         );
/// }
/// ```
///
/// The framework checks for `is ReadOnly` to determine if a resource is read-only.
/// Both `ReadOnlyResource` (which uses this mixin) and resources that directly
/// use this mixin will be treated as read-only.
mixin ReadOnly {
  // Marker mixin - no additional functionality needed
  // The framework checks for `is ReadOnly` to determine read-only behavior
}
