/// Dart Resource Framework Toolkit
///
/// An infrastructure-as-code toolkit written in Dart.
///
/// This library provides the core framework for defining and managing
/// infrastructure resources declaratively using Dart code.
library drft;

// Core exports
export 'src/core/stack.dart';
export 'src/core/resource.dart';
export 'src/core/dependent_resource.dart';
export 'src/core/provider.dart';
export 'src/core/mock_provider.dart';
export 'src/core/state.dart';
export 'src/core/plan.dart';
export 'src/core/executor.dart';
export 'src/core/dependency_graph.dart';

// Utilities
export 'src/utils/exceptions.dart';
export 'src/utils/package_root.dart';

// Serialization
export 'src/core/object_serialization.dart';
