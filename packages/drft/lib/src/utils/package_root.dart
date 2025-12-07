/// Utilities for finding the package root
library;

import 'dart:io';

import 'package:path/path.dart' as path;

/// Find the package root by looking for pubspec.yaml
///
/// Walks up the directory tree from [startPath] (or current directory)
/// until it finds a directory containing pubspec.yaml.
///
/// Returns the absolute path to the package root, or null if not found.
Future<String?> findPackageRoot({String? startPath}) async {
  var currentDir = startPath != null
      ? Directory(path.absolute(startPath))
      : Directory.current;

  // If startPath is a file, use its parent directory
  if (startPath != null) {
    final file = File(startPath);
    if (await file.exists()) {
      currentDir = file.parent;
    }
  }

  var dir = currentDir;
  while (true) {
    final pubspecFile = File(path.join(dir.path, 'pubspec.yaml'));
    if (await pubspecFile.exists()) {
      return dir.path;
    }

    final parent = dir.parent;
    // Stop if we've reached the filesystem root
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }

  return null;
}

/// Resolve a path relative to the package root
///
/// If [filePath] is already absolute, returns it as-is.
/// If [filePath] is relative and starts with `.drft/`, resolves it relative
/// to the package root. Otherwise, resolves it relative to the current directory.
Future<String> resolvePathRelativeToPackageRoot(String filePath) async {
  // If already absolute, return as-is
  if (path.isAbsolute(filePath)) {
    return filePath;
  }

  // If it starts with .drft/, resolve relative to package root
  if (filePath.startsWith('.drft/') || filePath == '.drft') {
    final packageRoot = await findPackageRoot();
    if (packageRoot != null) {
      return path.join(packageRoot, filePath);
    }
    // Fallback to current directory if package root not found
    return path.absolute(filePath);
  }

  // Otherwise, resolve relative to current directory
  return path.absolute(filePath);
}

