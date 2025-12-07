/// Stack loader - Execute stack files (similar to Grinder's approach)
library;

import 'dart:io';

import 'package:path/path.dart' as path;

/// Loads and executes a stack file
///
/// Similar to how Grinder works:
/// 1. CLI looks for drft_stack.dart (like tool/grind.dart)
/// 2. Executes that file with the command arguments
/// 3. The file calls drft() with those arguments
/// 4. drft() parses and executes the command
class StackLoader {
  /// Execute a stack file with command arguments
  ///
  /// The stack file should have a main() function that calls drft(args)
  static Future<int> executeStackFile({
    required String stackFile,
    required List<String> args,
  }) async {
    File? file = File(stackFile);
    if (!await file.exists()) {
      // Try common locations
      final commonPaths = [
        'drft_stack.dart',
        'tool/drft_stack.dart',
        'lib/drft_stack.dart',
      ];

      File? foundFile;
      for (final commonPath in commonPaths) {
        final testFile = File(commonPath);
        if (await testFile.exists()) {
          foundFile = testFile;
          break;
        }
      }

      if (foundFile == null) {
        throw FileSystemException(
          'Stack file not found: $stackFile\n'
          'Tried: $stackFile, ${commonPaths.join(', ')}\n'
          'Create a drft_stack.dart file that defines your stack and calls drft() from main().',
        );
      }
      file = foundFile;
    }

    // Check file extension
    if (!file.path.endsWith('.dart')) {
      throw ArgumentError('Stack file must be a Dart file (.dart)');
    }

    // Execute the file as a Dart script
    // The file should have: void main(List<String> args) { drft(args); }
    final absolutePath = path.absolute(file.path);
    final directory = path.dirname(absolutePath);

    // Run the file with dart run, passing the arguments
    final process = await Process.start(
      'dart',
      ['run', absolutePath, ...args],
      workingDirectory: directory,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;
    return exitCode;
  }
}
