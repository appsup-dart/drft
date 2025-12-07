/// Firebase App resource
library;

import 'package:drft/drft.dart';

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
class FirebaseApp extends Resource<FirebaseAppState> {
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

  /// App Store ID for iOS apps (optional)
  final String? appStoreId;

  /// SHA-1 fingerprints for Android apps (optional)
  final List<String>? sha1Fingerprints;

  const FirebaseApp({
    required String id,
    required this.projectId,
    required this.platform,
    required this.displayName,
    this.bundleId,
    this.packageName,
    this.appStoreId,
    this.sha1Fingerprints,
    List<Resource> dependencies = const [],
  }) : super(
          id: id,
          dependencies: dependencies,
        );
}
