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
/// Represents a Firebase project that can be created, updated, or deleted.
class FirebaseProject extends Resource<FirebaseProjectState> {
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
