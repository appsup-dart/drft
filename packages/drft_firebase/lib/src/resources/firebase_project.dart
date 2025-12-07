/// Firebase Project resource
library;

import 'package:drft/drft.dart';

/// State for a Firebase Project
class FirebaseProjectState extends ResourceState {
  FirebaseProjectState({
    required super.resource,
  });
}

/// Firebase Project resource
///
/// Represents a Firebase project that exists externally.
/// Firebase projects cannot be created, updated, or deleted through DRFT.
/// They must be managed through the Firebase Console or Google Cloud Console.
///
/// This resource serves as a data source to:
/// - Verify the project exists
/// - Read project information
/// - Provide project ID for other resources that depend on it
class FirebaseProject extends ReadOnlyResource<FirebaseProjectState> {
  /// The desired project ID (must be globally unique)
  final String projectId;

  /// Display name for the project
  final String displayName;

  const FirebaseProject({
    required String id,
    required this.projectId,
    required this.displayName,
    List<Resource> dependencies = const [],
  }) : super(
          id: id,
          dependencies: dependencies,
        );
}
