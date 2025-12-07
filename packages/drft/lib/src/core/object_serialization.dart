/// Generic object serialization using reflection
///
/// This utility can serialize any Dart object to JSON and deserialize it back,
/// as long as:
/// - The object is not cyclic (no circular references)
/// - The object has an appropriate constructor (default constructor with named parameters)
/// - All fields are JSON-serializable types
///
/// JSON structure:
/// ```json
/// {
///   ".type": "package_name.ClassName",
///   "property1": "value1",
///   "property2": "value2"
/// }
/// ```
library;

import 'dart:mirrors';

/// Custom serializer for a specific type
class CustomSerializer<T> {
  /// Convert a value of type T to JSON-serializable format
  final dynamic Function(T value) toJson;

  /// Convert a JSON value back to type T
  final T Function(dynamic value) fromJson;

  CustomSerializer({
    required this.toJson,
    required this.fromJson,
  });

  dynamic serialize(T value) => toJson(value);
  T deserialize(dynamic value) => fromJson(value);
}

/// Generic object serialization utility
class ObjectSerialization {
  /// Default instance for convenience
  static final ObjectSerialization instance = ObjectSerialization();

  /// Registry of custom serializers by type
  final Map<Type, CustomSerializer> _customSerializers = {};

  /// Private constructor - use [instance] for the default instance
  ObjectSerialization();

  /// Register a custom serializer for a specific type
  ///
  /// Example:
  /// ```dart
  /// ObjectSerialization.instance.registerCustomSerializer<Uri>(
  ///   CustomSerializer<Uri>(
  ///     toJson: (uri) => uri.toString(),
  ///     fromJson: (value) => Uri.parse(value as String),
  ///   ),
  /// );
  /// ```
  ///
  /// Note: The serializer will be used for any value that is an instance of T,
  /// even if the runtime type is different (e.g., Uri instances have runtime type
  /// `_SimpleUri`, but will match a serializer registered for `Uri`).
  void registerCustomSerializer<T>(CustomSerializer<T> serializer) {
    _customSerializers[T] = serializer;
  }

  /// Unregister a custom serializer for a specific type
  void unregisterCustomSerializer<T>() {
    _customSerializers.remove(T);
  }

  /// Clear all custom serializers
  void clearCustomSerializers() {
    _customSerializers.clear();
  }

  /// Serialize an object to JSON
  ///
  /// The resulting JSON will have:
  /// - `.type`: The qualified class name (package.ClassName)
  /// - All public instance fields as properties
  ///
  /// [fieldFilter] can be used to exclude certain fields from serialization.
  /// It receives the field name and should return true to include the field.
  Map<String, dynamic> toJson(
    dynamic object, {
    bool Function(String fieldName)? fieldFilter,
  }) {
    final mirror = reflect(object);
    final classMirror = mirror.type;
    final json = <String, dynamic>{};

    // Get qualified class name (package.ClassName)
    final qualifiedName = _getQualifiedName(classMirror);
    json['.type'] = qualifiedName;

    // Get all instance fields (including inherited ones)
    final allFields = <VariableMirror>[];
    ClassMirror? current = classMirror;
    while (current != null) {
      for (final declaration in current.declarations.values) {
        if (declaration is VariableMirror && !declaration.isStatic) {
          final fieldName = MirrorSystem.getName(declaration.simpleName);
          // Skip private fields
          if (fieldName.startsWith('_')) continue;
          // Skip if we've already seen this field (subclass overrides)
          if (allFields
              .any((f) => MirrorSystem.getName(f.simpleName) == fieldName)) {
            continue;
          }
          allFields.add(declaration);
        }
      }
      // Walk up the inheritance chain
      final superclass = current.superclass;
      if (superclass == null) {
        break;
      }
      current = superclass;
    }

    // Serialize all fields
    for (final declaration in allFields) {
      final fieldName = MirrorSystem.getName(declaration.simpleName);

      // Apply field filter if provided
      if (fieldFilter != null && !fieldFilter(fieldName)) continue;

      // Get the field value
      // mirror.getField should work for inherited fields too
      final fieldMirror = mirror.getField(declaration.simpleName);
      final value = fieldMirror.reflectee;

      // Convert value to JSON-serializable format
      json[fieldName] = _toJsonValue(value, seen: <dynamic>{});
    }

    return json;
  }

  /// Deserialize an object from JSON
  ///
  /// The JSON should have:
  /// - `.type`: The qualified class name (package.ClassName) (required)
  /// - All properties as fields
  ///
  /// [fieldMapper] can be used to transform field names or values during deserialization.
  /// It receives the field name and original value, and should return the mapped value.
  T fromJson<T>(
    Map<String, dynamic> json, {
    dynamic Function(String fieldName, dynamic value)? fieldMapper,
  }) {
    final typeName = json['.type'] as String?;
    if (typeName == null) {
      throw ArgumentError('JSON must contain a ".type" field');
    }

    // Parse qualified name into package and class name
    final lastDot = typeName.lastIndexOf('.');
    final className = lastDot >= 0 ? typeName.substring(lastDot + 1) : typeName;
    final packageName = lastDot >= 0 ? typeName.substring(0, lastDot) : null;

    // Find the class mirror
    final classMirror = _findClassMirror(className, packageName);
    if (classMirror == null) {
      throw ArgumentError(
        'Could not find class "$typeName". Make sure the package is imported and the class exists.',
      );
    }

    // Find the default constructor
    final constructor = _findDefaultConstructor(classMirror, className);
    if (constructor == null) {
      final available = classMirror.declarations.values
          .whereType<MethodMirror>()
          .where((m) => m.isConstructor)
          .map((m) => MirrorSystem.getName(m.simpleName))
          .join(', ');
      throw ArgumentError(
        'No default constructor found for $className. Available constructors: $available',
      );
    }

    // Build constructor arguments
    final args = <Symbol, dynamic>{};
    for (final param in constructor.parameters) {
      if (!param.isNamed) continue;

      final paramName = MirrorSystem.getName(param.simpleName);

      // Skip metadata fields
      if (paramName == '.type') continue;

      dynamic value;
      if (json.containsKey(paramName)) {
        value = json[paramName];
        // Apply field mapper if provided
        if (fieldMapper != null) {
          value = fieldMapper(paramName, value);
        }
        // Only convert if value is not already the correct type
        // This allows fieldMapper to return values that are already properly typed
        final expectedTypeMirror = param.type;
        if (value != null && !_isValueOfType(value, expectedTypeMirror)) {
          value = _fromJsonValue(value, expectedTypeMirror);
        } else {
          value ??= _fromJsonValue(value, expectedTypeMirror);
        }
      } else if (!param.isOptional) {
        throw ArgumentError(
          'Required parameter "$paramName" not found in JSON',
        );
      }

      if (value != null) {
        args[param.simpleName] = value;
      }
    }

    // Create instance
    final instanceMirror = classMirror.newInstance(
      const Symbol(''),
      [],
      args,
    );

    return instanceMirror.reflectee as T;
  }

  /// Get qualified name (package.ClassName) from a class mirror
  String _getQualifiedName(ClassMirror classMirror) {
    final className = MirrorSystem.getName(classMirror.simpleName);
    final packageName = _getPackageName(classMirror);

    if (packageName.isNotEmpty) {
      return '$packageName.$className';
    }
    return className;
  }

  /// Get package name from a class mirror
  String _getPackageName(ClassMirror classMirror) {
    var current = classMirror.owner;
    LibraryMirror? libraryMirror;
    while (current != null) {
      if (current is LibraryMirror) {
        libraryMirror = current;
        break;
      }
      current = current.owner;
    }

    if (libraryMirror != null) {
      final libraryUri = libraryMirror.uri;
      return _extractPackageName(libraryUri);
    }

    return '';
  }

  /// Extract package name from library URI
  String _extractPackageName(Uri uri) {
    if (uri.scheme == 'package') {
      return uri.pathSegments.first;
    }
    if (uri.scheme == 'file') {
      final path = uri.path;
      final packagesMatch = RegExp(r'packages/([^/]+)').firstMatch(path);
      if (packagesMatch != null) {
        return packagesMatch.group(1)!;
      }
    }
    return '';
  }

  /// Find a class mirror by name and optional package
  ClassMirror? _findClassMirror(String className, String? packageName) {
    final libraries = currentMirrorSystem().libraries;
    for (final library in libraries.values) {
      // Check package name if provided
      if (packageName != null) {
        final libraryUri = library.uri;
        final libPackageName = _extractPackageName(libraryUri);
        if (libPackageName != packageName) continue;
      }

      // Look for the class
      for (final declaration in library.declarations.values) {
        if (declaration is ClassMirror) {
          final declName = MirrorSystem.getName(declaration.simpleName);
          if (declName == className) {
            return declaration;
          }
        }
      }
    }

    return null;
  }

  /// Find the default constructor for a class
  MethodMirror? _findDefaultConstructor(
    ClassMirror classMirror,
    String className,
  ) {
    for (final decl in classMirror.declarations.values) {
      if (decl is MethodMirror && decl.isConstructor) {
        final constructorName = MirrorSystem.getName(decl.simpleName);
        // Default constructor has the same name as the class
        if (constructorName == className) {
          return decl;
        }
      }
    }
    return null;
  }

  /// Convert a value to JSON-serializable format
  ///
  /// Handles:
  /// - Primitive types: null, String, num, bool
  /// - Collections: List, Map
  /// - Custom serializers: Uses registered custom serializers
  /// - Objects: Recursively serialized using [toJson]
  ///
  /// Non-serializable types (functions, closures) are converted to strings,
  /// but cannot be deserialized back.
  ///
  /// Note: This does NOT handle Resource objects - they should be handled
  /// by ResourceSerialization to avoid infinite recursion.
  dynamic _toJsonValue(dynamic value, {Set<dynamic>? seen}) {
    seen ??= {};

    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;

    // Check for custom serializer
    // Check all registered types to see if value is an instance of that type
    for (final entry in _customSerializers.entries) {
      final registeredType = entry.key;
      if (_isInstanceOfType(value, registeredType)) {
        // Call the serializer - the toJson function accepts the registered type
        // We use a dynamic call to avoid type system issues
        return entry.value.serialize(value);
      }
    }

    if (value is List) {
      return value.map((e) => _toJsonValue(e, seen: seen)).toList();
    }
    if (value is Map) {
      return value
          .map((k, v) => MapEntry(k.toString(), _toJsonValue(v, seen: seen)));
    }

    // Check for cycles
    if (seen.contains(value)) {
      throw ArgumentError('Cyclic reference detected during serialization');
    }
    seen.add(value);

    try {
      // For other objects, recursively serialize
      // This handles nested objects but will fail for cyclic references
      return toJson(value, fieldFilter: null);
    } finally {
      seen.remove(value);
    }
  }

  /// Create a list of the exact type specified by the TypeMirror
  /// Uses reflection to create a list with the exact generic type
  dynamic _createTypedList(ClassMirror classMirror, List<dynamic> elements) {
    final instanceMirror = classMirror.newInstance(
      const Symbol('from'),
      [elements],
      {#growable: true},
    );

    return instanceMirror.reflectee;
  }

  /// Create a map of the exact type specified by the TypeMirror
  /// Uses reflection to create a map with the exact generic type
  dynamic _createTypedMap(
    ClassMirror classMirror,
    Map<dynamic, dynamic> entries,
  ) {
    final instanceMirror = classMirror.newInstance(
      const Symbol('from'),
      [entries],
    );

    return instanceMirror.reflectee;
  }

  /// Convert a JSON value back to its original type
  ///
  /// [expectedTypeMirror] can be provided to help with type conversion.
  dynamic _fromJsonValue(dynamic value, TypeMirror? expectedTypeMirror) {
    if (value == null) return null;

    if (expectedTypeMirror == null) return value;

    // Check for custom deserializer if expectedTypeMirror is provided
    final reflectedType = expectedTypeMirror.reflectedType;
    final customSerializer = _customSerializers[reflectedType];
    if (customSerializer != null) {
      return customSerializer.deserialize(value);
    }

    if (expectedTypeMirror.isAssignableTo(reflectType(List))) {
      if (value is! List) {
        throw ArgumentError('Value is not a List');
      }
      return _createTypedList(
        expectedTypeMirror as ClassMirror,
        value
            .map((e) => _fromJsonValue(e, expectedTypeMirror.typeArguments[0]))
            .toList(),
      );
    }

    if (expectedTypeMirror.isAssignableTo(reflectType(Map))) {
      if (value is! Map) {
        throw ArgumentError('Value is not a Map');
      }
      return _createTypedMap(
        expectedTypeMirror as ClassMirror,
        value.map(
          (k, v) => MapEntry(
            _fromJsonValue(k, expectedTypeMirror.typeArguments[0]),
            _fromJsonValue(v, expectedTypeMirror.typeArguments[1]),
          ),
        ),
      );
    }

    if (value is Map) {
      // Check if this is a serialized object (has .type field)
      if (value.containsKey('.type')) {
        return fromJson<dynamic>(value as Map<String, dynamic>);
      }
    }
    return value;
  }

  /// Check if a value is already of the expected type
  /// This is used to avoid unnecessary type conversions when fieldMapper
  /// returns values that are already properly typed
  bool _isValueOfType(dynamic value, TypeMirror? expectedTypeMirror) {
    if (value == null || expectedTypeMirror == null) return false;

    // For lists, we need to check if the runtime type matches
    // List<dynamic> from JSON should not match List<String>
    if (value is List && expectedTypeMirror is ClassMirror) {
      final classMirror = expectedTypeMirror;
      final typeName = MirrorSystem.getName(classMirror.simpleName);

      if (typeName == 'List') {
        // Check if the runtime type matches the expected type
        final runtimeTypeString = value.runtimeType.toString();
        // If runtime type is exactly List (which means List<dynamic>), it needs conversion
        if (runtimeTypeString == 'List' ||
            runtimeTypeString == '_GrowableList') {
          return false; // Needs conversion
        }
        // If runtime type matches expected type, it's already correct
        final expectedType = expectedTypeMirror.reflectedType;
        if (value.runtimeType == expectedType) {
          return true;
        }
        // For other cases, be conservative and convert
        return false;
      }
    }

    // For non-list types, use _isInstanceOfType
    final expectedType = expectedTypeMirror.reflectedType;
    return _isInstanceOfType(value, expectedType);
  }

  /// Check if a value is an instance of a given type
  /// This handles cases where runtime type differs from the declared type
  /// (e.g., Uri instances have runtime type _SimpleUri)
  bool _isInstanceOfType(dynamic value, Type type) {
    final typeString = type.toString();
    final runtimeTypeString = value.runtimeType.toString();

    // Special handling for common types where runtime type differs
    // Uri instances have runtime type _SimpleUri, but are instances of Uri
    if (typeString == 'Uri') {
      return value is Uri;
    }

    // For other types, try exact match first
    if (runtimeTypeString == typeString) {
      return true;
    }

    // For generic types, extract base type
    if (typeString.contains('<')) {
      final baseType = typeString.split('<').first.trim();
      if (runtimeTypeString.startsWith(baseType)) {
        return true;
      }
    }

    return false;
  }
}
