/// Firebase Provider implementation
library;

import 'package:drft/drft.dart';
import 'package:firebase_management/firebase_management.dart';
import '../resources/firebase_app.dart';
import '../resources/firebase_project.dart';

/// Firebase Provider for managing Firebase projects and apps
class FirebaseProvider extends Provider {
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

  @override
  bool canHandle(Resource resource) {
    return resource is FirebaseProject || resource is FirebaseApp;
  }

  @override
  Future<ResourceState> createResource(Resource resource) async {
    await _ensureInitialized();

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
  Future<ResourceState> readResource(Resource resource) async {
    await _ensureInitialized();

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
    Resource desired,
  ) async {
    await _ensureInitialized();

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
      appStoreId: app.appStoreId ?? resource.appStoreId,
      // Note: sha1Fingerprints might not be available in app metadata
      // Keep the desired value if not available from Firebase
      sha1Fingerprints: resource.sha1Fingerprints,
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
      appStoreId: app.appStoreId ?? resource.appStoreId,
      // Note: sha1Fingerprints might not be available in app metadata
      // Keep the desired value if not available from Firebase
      sha1Fingerprints: resource.sha1Fingerprints,
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
    // Firebase apps have limited update capabilities
    // For now, we'll just verify the app exists and return updated state
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
