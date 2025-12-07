/// Refresh command - Refresh state from actual infrastructure
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:drft/drft.dart';

/// Refresh command implementation
class RefreshCommand {
  Future<int> run({
    required DrftStack stack,
    required List<String> args,
  }) async {
    final parser = ArgParser()
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Show detailed output and stack traces on errors',
      );

    final results = parser.parse(args);
    final verbose = results['verbose'] == true;

    try {
      // Refresh state
      stdout.writeln('Refreshing state from infrastructure...\n');
      final refreshedState = await stack.refresh();

      // Show results
      stdout.writeln('✅ State refreshed successfully!');
      stdout.writeln('   Stack: ${refreshedState.stackName}');
      stdout.writeln('   Resources: ${refreshedState.resources.length}');
      
      if (refreshedState.resources.isNotEmpty) {
        stdout.writeln('\nRefreshed resources:');
        for (final resourceState in refreshedState.resources.values) {
          stdout.writeln('   - ${resourceState.resourceId} (${resourceState.resource.runtimeType})');
        }
      }

      return 0;
    } catch (e, stackTrace) {
      stderr.writeln('Error refreshing state: $e');
      if (verbose) {
        stderr.writeln('\nStack trace:');
        stderr.writeln(stackTrace);
      }
      return 1;
    }
  }
}

