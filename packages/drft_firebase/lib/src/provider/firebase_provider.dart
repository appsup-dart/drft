/// Firebase Provider implementation
library;

import 'package:drft/drft.dart';
import 'package:firebase_management/firebase_management.dart';
import '../resources/firebase_app.dart';
import '../resources/firebase_project.dart';
import '../resources/firebase_resource.dart';

/// Firebase Provider for managing Firebase projects and apps
///
/// This provider uses the typed provider pattern with [FirebaseResource] as the
/// base type, allowing it to handle both [FirebaseApp] and [FirebaseProject]
/// resources with type safety.
///
/// The [canHandle] method is automatically implemented to check if a resource
/// is a [FirebaseResource]. Methods receive [FirebaseResource] directly, so
/// type checking is only needed to determine the specific resource type
/// (FirebaseApp vs FirebaseProject).
class FirebaseProvider extends Provider<FirebaseResource> {
  FirebaseManagement? _firebaseManagement;
  Credential? _credentials;

  /// Create a Firebase provider
  ///
  /// [credentials] can be provided directly, or the provider will attempt
  /// to use Application Default Credentials.
  FirebaseProvider({
    Credential? credentials,
  })  : _credentials = credentials,
        super(
          name: 'firebase',
          version: '0.1.0',
        );

  @override
  Future<void> configure(Map<String, dynamic> config) async {
    // Configuration can include project-specific settings
    // Currently not used, but available for future extensions
  }

  @override
  Future<void> initialize() async {
    if (_firebaseManagement != null) return;

    // Use provided credentials or try Application Default Credentials
    final credentials = _credentials ?? Credentials.applicationDefault();

    if (credentials == null) {
      throw DrftException(
        'Firebase credentials not found. '
        'Please provide credentials or set up Application Default Credentials.',
      );
    }

    _firebaseManagement = FirebaseManagement(credentials);
  }

  @override
  Future<void> dispose() async {
    _firebaseManagement = null;
  }

  // canHandle() is automatically implemented by Provider<FirebaseResource>
  // It checks if resource is FirebaseResource, which both FirebaseApp and
  // FirebaseProject extend

  @override
  Future<ResourceState> createResource(FirebaseResource resource) async {
    await _ensureInitialized();

    // Type checking still needed to determine which specific resource type
    if (resource is FirebaseProject) {
      return await _createFirebaseProject(resource);
    } else if (resource is FirebaseApp) {
      return await _createFirebaseApp(resource);
    }

    throw ProviderNotFoundException(
      'Resource type ${resource.runtimeType} not supported by Firebase provider',
    );
  }

  @override
  Future<ResourceState> readResource(FirebaseResource resource) async {
    await _ensureInitialized();

    // Type checking still needed to determine which specific resource type
    if (resource is FirebaseProject) {
      return await _readFirebaseProject(resource);
    } else if (resource is FirebaseApp) {
      return await _readFirebaseApp(resource);
    }

    throw ProviderNotFoundException(
      'Resource type ${resource.runtimeType} not supported by Firebase provider',
    );
  }

  @override
  Future<ResourceState> updateResource(
    ResourceState current,
    FirebaseResource desired,
  ) async {
    await _ensureInitialized();

    // Type checking still needed to determine which specific resource type
    if (desired is FirebaseProject) {
      return await _updateFirebaseProject(current, desired);
    } else if (desired is FirebaseApp) {
      return await _updateFirebaseApp(current, desired);
    }

    throw ProviderNotFoundException(
      'Resource type ${desired.runtimeType} not supported by Firebase provider',
    );
  }

  @override
  Future<void> deleteResource(ResourceState state) async {
    await _ensureInitialized();

    if (state.resource is FirebaseProject) {
      await _deleteFirebaseProject(state);
    } else if (state.resource is FirebaseApp) {
      await _deleteFirebaseApp(state);
    } else {
      throw ProviderNotFoundException(
        'Resource type ${state.resource.runtimeType} not supported by Firebase provider',
      );
    }
  }

  // Firebase Project operations

  Future<ResourceState> _createFirebaseProject(FirebaseProject resource) async {
    throw UnsupportedError(
      'Creating Firebase projects is not supported. '
      'Please create projects through the Firebase Console or Google Cloud Console.',
    );
  }

  Future<ResourceState> _readFirebaseProject(FirebaseProject resource) async {
    final projects = await _firebaseManagement!.projects.listFirebaseProjects();
    final project = projects.firstWhere(
      (p) => p.projectId == resource.projectId,
      orElse: () => throw DrftException(
        'Firebase project ${resource.projectId} not found',
      ),
    );

    return FirebaseProjectState(
      resource: FirebaseProject(
        id: resource.id,
        projectId: project.projectId,
        displayName: project.displayName,
      ),
    );
  }

  Future<ResourceState> _updateFirebaseProject(
    ResourceState current,
    FirebaseProject desired,
  ) async {
    // Firebase projects have limited update capabilities
    // For now, we'll just verify the project exists and return updated state
    return await _readFirebaseProject(desired);
  }

  Future<void> _deleteFirebaseProject(ResourceState state) async {
    throw UnsupportedError(
      'Deleting Firebase projects is not supported. '
      'Please delete projects through the Firebase Console or Google Cloud Console.',
    );
  }

  // Firebase App operations

  Future<ResourceState> _createFirebaseApp(FirebaseApp resource) async {
    dynamic app;

    switch (resource.platform) {
      case FirebaseAppPlatform.ios:
        if (resource.bundleId == null) {
          throw DrftException(
            'bundleId is required for iOS apps',
          );
        }
        app = await _firebaseManagement!.apps.createIosApp(
          resource.projectId,
          displayName: resource.displayName,
          bundleId: resource.bundleId!,
        );
        break;

      case FirebaseAppPlatform.android:
        if (resource.packageName == null) {
          throw DrftException(
            'packageName is required for Android apps',
          );
        }
        app = await _firebaseManagement!.apps.createAndroidApp(
          resource.projectId,
          displayName: resource.displayName,
          packageName: resource.packageName!,
        );
        break;

      case FirebaseAppPlatform.web:
        app = await _firebaseManagement!.apps.createWebApp(
          resource.projectId,
          displayName: resource.displayName,
        );
        break;
    }

    // Create a resource from the actual Firebase app data
    // This represents what actually exists in Firebase after creation
    final actualPlatform = _convertFromAppPlatform(app.platform);
    final actualResource = FirebaseApp(
      id: resource.id,
      projectId: resource.projectId,
      platform: actualPlatform,
      displayName: app.displayName ?? resource.displayName,
      bundleId: app.bundleId ?? resource.bundleId,
      packageName: app.packageName ?? resource.packageName,
    );

    return FirebaseAppState(
      resource: actualResource,
      appId: app.appId,
    );
  }

  Future<ResourceState> _readFirebaseApp(FirebaseApp resource) async {
    final apps = await _firebaseManagement!.apps.listFirebaseApps(
      resource.projectId,
    );
    final app = apps.firstWhere(
      (a) => _matchesApp(a, resource),
      orElse: () => throw ResourceNotFoundException(
        'Firebase app not found for project ${resource.projectId}',
      ),
    );

    // Create a resource from the actual Firebase app data
    // This represents what actually exists in Firebase, not what we desired
    final actualPlatform = _convertFromAppPlatform(app.platform);
    final actualResource = FirebaseApp(
      id: resource.id,
      projectId: resource.projectId,
      platform: actualPlatform,
      displayName: app.displayName ?? resource.displayName,
      bundleId: app.bundleId ?? resource.bundleId,
      packageName: app.packageName ?? resource.packageName,
    );

    return FirebaseAppState(
      resource: actualResource,
      appId: app.appId,
    );
  }

  Future<ResourceState> _updateFirebaseApp(
    ResourceState current,
    FirebaseApp desired,
  ) async {
    if (current is! FirebaseAppState) {
      throw DrftException('Invalid state type for Firebase app update');
    }

    final currentApp = current.resource as FirebaseApp;
    final appId = current.appId;

    // Verify the app still exists and get current state
    final apps = await _firebaseManagement!.apps.listFirebaseApps(
      desired.projectId,
    );
    apps.firstWhere(
      (a) => a.appId == appId,
      orElse: () => throw ResourceNotFoundException(
        'Firebase app with ID $appId not found in project ${desired.projectId}',
      ),
    );

    // Check for immutable property changes
    if (desired.platform != currentApp.platform) {
      throw DrftException(
        'Cannot change platform of an existing Firebase app. '
        'Current: ${currentApp.platform}, Desired: ${desired.platform}',
      );
    }

    if (desired.bundleId != null &&
        currentApp.bundleId != null &&
        desired.bundleId != currentApp.bundleId) {
      throw DrftException(
        'Cannot change bundleId of an existing iOS Firebase app. '
        'Current: ${currentApp.bundleId}, Desired: ${desired.bundleId}',
      );
    }

    if (desired.packageName != null &&
        currentApp.packageName != null &&
        desired.packageName != currentApp.packageName) {
      throw DrftException(
        'Cannot change packageName of an existing Android Firebase app. '
        'Current: ${currentApp.packageName}, Desired: ${desired.packageName}',
      );
    }

    // Determine what needs to be updated
    final needsDisplayNameUpdate =
        desired.displayName != currentApp.displayName;

    // Check if any updates are needed
    if (!needsDisplayNameUpdate) {
      // No changes needed, return current state
      return current;
    }

    // Update the app using the updateApp method
    final platform = _convertPlatform(desired.platform);
    await _firebaseManagement!.apps.updateApp(
      desired.projectId,
      platform,
      appId,
      displayName: desired.displayName,
    );
    return await _readFirebaseApp(desired);
  }

  Future<void> _deleteFirebaseApp(ResourceState state) async {
    if (state is! FirebaseAppState) {
      throw DrftException('Invalid state type for Firebase app deletion');
    }

    // Note: App deletion might not be directly supported by firebase_management
    // This would need to be implemented based on the actual API capabilities
    throw DrftException(
      'Deleting Firebase apps is not yet implemented',
    );
  }

  // Helper methods

  Future<void> _ensureInitialized() async {
    if (_firebaseManagement == null) {
      await initialize();
    }
  }

  AppPlatform _convertPlatform(FirebaseAppPlatform platform) {
    switch (platform) {
      case FirebaseAppPlatform.ios:
        return AppPlatform.ios;
      case FirebaseAppPlatform.android:
        return AppPlatform.android;
      case FirebaseAppPlatform.web:
        return AppPlatform.web;
    }
  }

  FirebaseAppPlatform _convertFromAppPlatform(AppPlatform platform) {
    switch (platform) {
      case AppPlatform.ios:
        return FirebaseAppPlatform.ios;
      case AppPlatform.android:
        return FirebaseAppPlatform.android;
      case AppPlatform.web:
        return FirebaseAppPlatform.web;
      case AppPlatform.unspecified:
      case AppPlatform.any:
        // Fallback to desired platform if unspecified/any
        // This shouldn't happen in practice, but handle it gracefully
        throw DrftException(
          'Unspecified or any platform from Firebase app - cannot determine platform',
        );
    }
  }

  bool _matchesApp(dynamic app, FirebaseApp resource) {
    // Match by platform and either bundleId/packageName or displayName
    final appPlatform = _convertPlatform(resource.platform);
    if (app.platform != appPlatform) return false;

    // Try to match by bundleId/packageName if available
    if (resource.bundleId != null && app.bundleId == resource.bundleId) {
      return true;
    }
    if (resource.packageName != null &&
        app.packageName == resource.packageName) {
      return true;
    }

    // Fall back to display name matching
    return app.displayName == resource.displayName;
  }
}
