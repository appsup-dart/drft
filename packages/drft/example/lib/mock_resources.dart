import 'package:drft/drft.dart';

/// Example resource: A simple web server
class WebServer extends Resource {
  final String hostname;
  final int port;
  final String? environment;

  const WebServer({
    required super.id,
    required this.hostname,
    this.port = 8080,
    this.environment,
    super.dependencies,
  });
}

/// Example resource: A database
class Database extends Resource {
  final String name;
  final String engine;
  final int? port;

  const Database({
    required super.id,
    required this.name,
    required this.engine,
    this.port,
    super.dependencies,
  });
}

/// Example resource: A load balancer
class LoadBalancer extends Resource {
  final List<String> backendServers;
  final int port;

  const LoadBalancer({
    required super.id,
    required this.backendServers,
    this.port = 80,
    super.dependencies,
  });
}

/// State for App Store Bundle ID resource
class AppStoreBundleIdState extends ResourceState {
  /// The bundle ID assigned by App Store (read-only property)
  /// This is assigned by the provider and not part of the Resource
  final String bundleId;

  AppStoreBundleIdState({
    required super.resource,
    required this.bundleId,
  });
}

/// Example resource: App Store Bundle ID
///
/// When created, the provider (App Store) assigns a bundle ID that we need
/// for other resources. This demonstrates a resource with read-only properties.
class AppStoreBundleId extends Resource<AppStoreBundleIdState> {
  final String name;
  final String platform;

  const AppStoreBundleId({
    required super.id,
    required this.name,
    required this.platform,
    super.dependencies,
  });
}

/// State for Provisioning Profile resource
class ProvisioningProfileState extends ResourceState {
  /// ProvisioningProfileState has no read-only properties.
  /// All properties (bundleId, type, certificates) are part of the Resource.
  /// This demonstrates a ResourceState that only contains the Resource.

  ProvisioningProfileState({
    required super.resource,
  });
}

/// Example resource: Provisioning Profile
///
/// This resource needs the bundle ID that was assigned by App Store when
/// the AppStoreBundleId was created. Since the bundle ID is read-only,
/// we use DependentResource to build this after the Bundle ID is created.
class ProvisioningProfile extends Resource<ProvisioningProfileState> {
  final String bundleId; // Read-only property from App Store
  final String type;
  final List<String> certificates;

  const ProvisioningProfile({
    required super.id,
    required this.bundleId,
    required this.type,
    this.certificates = const [],
    super.dependencies,
  });
}
