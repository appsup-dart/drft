/// Dependent Resource - Resources that depend on read-only properties
///
/// Some resources need properties from other resources that are only available
/// after those resources are created. For example:
/// - App Store Bundle ID: Created with a name, but App Store assigns an ID
/// - Provisioning Profile: Needs the Bundle ID, which isn't available until
///   the Bundle ID resource is created
///
/// DependentResource allows you to define a resource that is built after
/// its dependencies are created, using a builder function that receives
/// the states of the dependencies.
library;

import 'resource.dart';
import 'state.dart';

/// A resource that depends on read-only properties from other resources
///
/// The resource is built after its dependencies are created, using a builder
/// function that receives the states of the dependencies.
///
/// Example:
/// ```dart
/// final bundleId = AppStoreBundleId(
///   id: 'bundle.myapp',
///   name: 'com.example.myapp',
///   platform: 'ios',
/// );
///
/// final provisioningProfile = DependentResource.single(
///   id: 'profile.main',
///   dependency: bundleId,
///   builder: (AppStoreBundleIdState bundleIdState) {
///     // Extract the read-only property using the typed getter
///     final bundleIdValue = bundleIdState.bundleId;
///
///     return ProvisioningProfile(
///       id: 'profile.main',
///       bundleId: bundleIdValue,  // Read-only property from App Store
///       type: 'development',
///       certificates: ['cert1', 'cert2'],
///     );
///   },
/// );
/// ```
///
class DependentResource<T extends ResourceState> extends Resource {
  /// Builder function that creates the actual resource from dependency states
  ///
  /// The function receives a list of dependency states in the same order
  /// as the dependencies list. The states contain the read-only properties
  /// that were assigned after creation.
  final Resource Function(List<ResourceState> dependencyStates) builder;

  /// Create a dependent resource
  ///
  /// [id] is the identifier for this resource
  /// [dependencies] are the resources this depends on (must be created first)
  /// [builder] is a function that builds the actual resource from dependency states
  DependentResource({
    required super.id,
    required super.dependencies,
    required this.builder,
  });

  /// Create a dependent resource with a single dependency
  ///
  /// This is a convenience constructor for the common case where a resource
  /// depends on a single other resource. The builder receives the dependency's
  /// ResourceState directly, making it easier to access.
  ///
  /// Example:
  /// ```dart
  /// final profile = DependentResource.single(
  ///   id: 'profile.main',
  ///   dependency: bundleId,
  ///   builder: (AppStoreBundleIdState bundleIdState) {
  ///     // Use typed getter to access read-only property
  ///     final bundleIdValue = bundleIdState.bundleId;
  ///     return ProvisioningProfile(
  ///       id: 'profile.main',
  ///       bundleId: bundleIdValue,
  ///       type: 'development',
  ///     );
  ///   },
  /// );
  /// ```
  factory DependentResource.single({
    required String id,
    required Resource<T> dependency,
    required Resource Function(T dependencyState) builder,
  }) {
    return DependentResource<T>(
      id: id,
      dependencies: [dependency],
      builder: (List<ResourceState> states) => builder(states.first as T),
    );
  }

  /// Build the resource from dependency states
  ///
  /// This should be called after all dependencies have been created.
  /// The builder function will receive the states in the same order as
  /// the dependencies list.
  Resource build(List<ResourceState> dependencyStates) {
    assert(
      dependencyStates.length == dependencies.length &&
          List.generate(
            dependencies.length,
            (i) => dependencyStates[i].resourceId == dependencies[i].id,
          ).every((match) => match),
      'Dependency states must match dependencies: '
      'length ${dependencyStates.length} vs ${dependencies.length}, '
      'and states must match in order',
    );

    return builder(dependencyStates);
  }
}
