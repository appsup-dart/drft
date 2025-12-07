/// Firebase App resource
library;

import 'package:drft/drft.dart';
import 'firebase_resource.dart';

/// Platform types for Firebase apps
enum FirebaseAppPlatform {
  ios,
  android,
  web,
}

/// State for a Firebase App
class FirebaseAppState extends ResourceState {
  /// The app ID assigned by Firebase (read-only)
  final String appId;

  FirebaseAppState({
    required super.resource,
    required this.appId,
  });
}

/// Firebase App resource
///
/// Represents a Firebase app (iOS, Android, or Web) within a Firebase project.
class FirebaseApp extends FirebaseResource<FirebaseAppState> {
  /// The Firebase project ID this app belongs to
  final String projectId;

  /// The platform of the app
  final FirebaseAppPlatform platform;

  /// Display name of the app
  final String displayName;

  /// Bundle ID for iOS apps
  final String? bundleId;

  /// Package name for Android apps
  final String? packageName;

  const FirebaseApp({
    required String id,
    required this.projectId,
    required this.platform,
    required this.displayName,
    this.bundleId,
    this.packageName,
    List<Resource> dependencies = const [],
  }) : super(
          id: id,
          dependencies: dependencies,
        );
}
