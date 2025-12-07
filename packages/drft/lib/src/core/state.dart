/// State management for tracking infrastructure state
library;

import 'dart:convert';
import 'dart:io';

import '../utils/exceptions.dart';
import '../utils/package_root.dart';
import 'resource.dart' show Resource;
import 'resource_serialization.dart';
import 'resource_state_serialization.dart';

/// Base class for resource states
///
/// ResourceState represents the actual state of a resource in infrastructure.
/// It contains:
/// - A Resource instance with the actual current values (may differ from desired)
/// - Optional read-only properties assigned by the provider
///
/// By requiring a Resource instance, we ensure that Resource and ResourceState
/// properties stay in sync - there's no duplication that can get out of sync.
///
/// Subclasses can add read-only properties (e.g., IDs assigned by providers).
///
/// **Serialization Requirements:**
/// ResourceStates are automatically serialized to JSON for state persistence.
/// All public fields (except `resource`) must be JSON-serializable types:
/// - `String`, `num`, `bool`, `null`
/// - `List` (of serializable types)
/// - `Map` (with string keys and serializable values)
///
/// **Non-serializable types** (functions, closures, complex objects) will be
/// converted to strings during serialization, but **cannot be deserialized**.
/// This will cause a `TypeError` if the field is required. Make such fields
/// optional if they're not needed for state persistence.
class ResourceState {
  /// The resource with actual current values
  /// This represents the actual state of the resource in infrastructure.
  /// It may differ from the desired Resource if changes were made outside DRFT.
  final Resource resource;

  ResourceState({
    required this.resource,
  });

  /// Resource identifier (convenience getter)
  String get resourceId => resource.id;
}

/// Represents the complete state of a stack
class State {
  /// Version of the state format
  final String version;

  /// Name of the stack
  final String stackName;

  /// Map of resource states by resource ID
  final Map<String, ResourceState> resources;

  /// Metadata about the state
  final Map<String, dynamic> metadata;

  State({
    required this.version,
    required this.stackName,
    required this.resources,
    this.metadata = const {},
  });

  /// Create an empty state
  factory State.empty({required String stackName}) {
    return State(
      version: '1.0',
      stackName: stackName,
      resources: {},
    );
  }

  /// Create state from a list of resources
  factory State.fromResources(List<Resource> resources, {String? stackName}) {
    final resourceStates = <String, ResourceState>{};

    for (final resource in resources) {
      // Create a basic ResourceState with the resource
      // The actual typed state with read-only properties will be created
      // when the resource is created by the provider
      resourceStates[resource.id] = ResourceState(
        resource: resource,
      );
    }

    return State(
      version: '1.0',
      stackName: stackName ?? 'default',
      resources: resourceStates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'stack': stackName,
      'resources': resources.map(
        (key, value) => MapEntry(key, ResourceStateSerialization.toJson(value)),
      ),
      'metadata': metadata,
    };
  }

  factory State.fromJson(Map<String, dynamic> json) {
    final resources = <String, ResourceState>{};
    final resourcesJson = json['resources'] as Map<String, dynamic>;

    // First pass: deserialize all resources without dependencies
    // This ensures all resources are in the map before we try to look them up
    // Temporarily remove dependencies from JSON to avoid reconstruction in first pass
    for (final entry in resourcesJson.entries) {
      final resourceStateJson =
          Map<String, dynamic>.from(entry.value as Map<String, dynamic>);
      final resourceJson =
          resourceStateJson['resource'] as Map<String, dynamic>?;

      // Temporarily remove dependencies to avoid reconstruction in first pass
      final dependencyIds =
          resourceJson?.remove('dependencies') as List<dynamic>?;

      // Deserialize without dependencies (they'll be reconstructed in second pass)
      resources[entry.key] = ResourceStateSerialization.fromJson(
        resourceStateJson,
        (id) =>
            throw StateError('Dependency "$id" not found during first pass'),
      );

      // Restore dependencies in the original JSON for second pass
      if (dependencyIds != null && resourceJson != null) {
        resourceJson['dependencies'] = dependencyIds;
      }
    }

    // Second pass: reconstruct dependencies using getDependency
    // Now all resources are in the map, so getDependency can find them
    for (final entry in resourcesJson.entries) {
      final resourceState = resources[entry.key]!;
      final resourceJson = entry.value as Map<String, dynamic>;
      final resourceStateJson =
          resourceJson['resource'] as Map<String, dynamic>?;

      if (resourceStateJson != null) {
        // Check if there are dependencies to reconstruct
        final dependencyIds =
            (resourceStateJson['dependencies'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                <String>[];

        if (dependencyIds.isNotEmpty) {
          // Deserialize resource again with getDependency to reconstruct dependencies
          Resource<ResourceState> getDependency(String id) {
            final resource = resources[id]?.resource;
            if (resource == null) {
              throw StateError('Dependency "$id" not found in state');
            }
            return resource;
          }

          final resource = ResourceSerialization.fromJson(
            resourceStateJson,
            getDependency,
          );

          // Update the state with the reconstructed resource, preserving typed state properties
          resources[entry.key] = ResourceStateSerialization.copyWithResource(
            resourceState,
            resource,
            getDependency,
          );
        }
      }
    }

    return State(
      version: json['version'] as String,
      stackName: json['stack'] as String,
      resources: resources,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map? ?? {},
      ),
    );
  }
}

/// Manages state persistence and loading
class StateManager {
  final String _stateFilePath;
  final String _lockFilePath;
  bool _isLocked = false;
  String? _resolvedStateFilePath;
  String? _resolvedLockFilePath;

  StateManager({
    String? stateFilePath,
  })  : _stateFilePath = stateFilePath ?? '.drft/state.json',
        _lockFilePath = '${stateFilePath ?? '.drft/state.json'}.lock';

  /// Get the resolved state file path (relative to package root)
  Future<String> get stateFilePath async {
    _resolvedStateFilePath ??=
        await resolvePathRelativeToPackageRoot(_stateFilePath);
    return _resolvedStateFilePath!;
  }

  /// Get the resolved lock file path (relative to package root)
  Future<String> get lockFilePath async {
    _resolvedLockFilePath ??=
        await resolvePathRelativeToPackageRoot(_lockFilePath);
    return _resolvedLockFilePath!;
  }

  /// Load state from file
  Future<State> load() async {
    final file = await _getStateFile();
    if (!await file.exists()) {
      return State.empty(stackName: 'default');
    }

    try {
      final contents = await file.readAsString();
      final json = _parseJson(contents);
      return State.fromJson(json);
    } catch (e) {
      final resolvedPath = await stateFilePath;
      throw StateException('Failed to load state from $resolvedPath', e);
    }
  }

  /// Save state to file
  Future<void> save(State state) async {
    final file = await _getStateFile();
    final directory = file.parent;

    // Ensure directory exists
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    try {
      final json = state.toJson();
      final contents = _encodeJson(json);
      await file.writeAsString(contents);
    } catch (e) {
      final resolvedPath = await stateFilePath;
      throw StateException('Failed to save state to $resolvedPath', e);
    }
  }

  /// Lock state file (for concurrent access)
  Future<void> lock() async {
    if (_isLocked) return;

    final lockFile = await _getLockFile();
    final directory = lockFile.parent;

    // Ensure directory exists
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Try to create lock file (simple file-based locking)
    // In a production system, you might want more sophisticated locking
    var attempts = 0;
    const maxAttempts = 10;
    const retryDelay = Duration(milliseconds: 100);

    while (attempts < maxAttempts) {
      try {
        if (await lockFile.exists()) {
          // Lock file exists, wait and retry
          await Future.delayed(retryDelay);
          attempts++;
          continue;
        }

        // Create lock file with current process info
        await lockFile.writeAsString(
          'pid: $pid\ntimestamp: ${DateTime.now().toIso8601String()}\n',
        );
        _isLocked = true;
        return;
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          throw StateException('Failed to acquire state lock', e);
        }
        await Future.delayed(retryDelay);
      }
    }

    throw StateException(
      'Failed to acquire state lock after $maxAttempts attempts',
    );
  }

  /// Unlock state file
  Future<void> unlock() async {
    if (!_isLocked) return;

    final lockFile = await _getLockFile();
    try {
      if (await lockFile.exists()) {
        await lockFile.delete();
      }
      _isLocked = false;
    } catch (e) {
      // Log error but don't throw - unlock should be best effort
      _isLocked = false;
    }
  }

  /// Get the state file
  Future<File> _getStateFile() async {
    final resolvedPath = await stateFilePath;
    return File(resolvedPath);
  }

  /// Get the lock file
  Future<File> _getLockFile() async {
    final resolvedPath = await lockFilePath;
    return File(resolvedPath);
  }

  /// Get current process ID (platform-specific)
  int get pid {
    // This is a simplified version - in production you'd use platform-specific code
    // For now, we'll use a hash of the current time as a pseudo-PID
    return DateTime.now().millisecondsSinceEpoch % 100000;
  }

  /// Parse JSON string
  Map<String, dynamic> _parseJson(String jsonString) {
    // Using dart:convert for JSON parsing
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Encode JSON
  String _encodeJson(Map<String, dynamic> json) {
    // Using dart:convert for JSON encoding
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}
