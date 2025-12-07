/// Base class for all Firebase resources
library;

import 'package:drft/drft.dart';

/// Base class for Firebase resources
///
/// This base class allows the FirebaseProvider to handle multiple
/// Firebase resource types (FirebaseApp, FirebaseProject, etc.)
/// through a single typed provider interface.
///
/// Note: FirebaseProject extends this class directly (not ReadOnlyResource)
/// but the provider methods handle read-only behavior by throwing errors
/// for unsupported operations.
abstract class FirebaseResource<StateType extends ResourceState>
    extends Resource<StateType> {
  const FirebaseResource({
    required super.id,
    super.dependencies = const [],
  });
}
