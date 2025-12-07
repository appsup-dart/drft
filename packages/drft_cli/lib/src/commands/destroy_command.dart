/// Destroy command - Destroy all resources in the stack
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:drft/drft.dart';

/// Destroy command implementation
class DestroyCommand {
  Future<int> run({
    DrftStack? stack,
    required List<String> args,
  }) async {
    final parser = ArgParser()
      ..addFlag(
        'auto-approve',
        negatable: false,
        help: 'Skip interactive approval',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Show detailed output and stack traces on errors',
      );

    final results = parser.parse(args);
    final verbose = results['verbose'] == true;

    try {
      if (stack == null) {
        stderr.writeln('Error: No stack provided');
        return 1;
      }

      // Load current state
      final currentState = await stack.stateManager.load();

      if (currentState.resources.isEmpty) {
        stdout.writeln('No resources to destroy.');
        return 0;
      }

      // Show what will be destroyed
      stdout.writeln('The following resources will be destroyed:');
      for (final resourceState in currentState.resources.values) {
        stdout.writeln(
            '  - ${resourceState.resourceId} (${resourceState.resource.runtimeType})');
      }
      stdout.writeln('');

      // Ask for approval unless auto-approve
      if (results['auto-approve'] != true) {
        stdout.write('Do you want to destroy these resources? (yes/no): ');
        final input = stdin.readLineSync()?.toLowerCase();
        if (input != 'yes' && input != 'y') {
          stdout.writeln('Destroy cancelled.');
          return 0;
        }
        stdout.writeln('');
      }

      // Destroy all resources
      stdout.writeln('Destroying resources...\n');
      final result = await stack.destroy();

      // Show results
      stdout.writeln(result.summary);

      if (result.success) {
        stdout.writeln('✅ Destroy completed successfully!');
        return 0;
      } else {
        stderr.writeln('❌ Destroy failed!');
        for (final opResult in result.operations) {
          if (!opResult.success) {
            final resourceId = opResult.operation.resource?.id ?? 
                opResult.operation.currentState?.resourceId ?? 'unknown';
            stderr.writeln('  Failed: ${opResult.operation.type.name} $resourceId - ${opResult.error}');
            if (verbose && opResult.stackTrace != null) {
              stderr.writeln('    Stack trace:');
              stderr.writeln(opResult.stackTrace.toString());
            }
          }
        }
        return 1;
      }
    } catch (e, stackTrace) {
      stderr.writeln('Error destroying resources: $e');
      if (verbose) {
        stderr.writeln('\nStack trace:');
        stderr.writeln(stackTrace);
      }
      return 1;
    }
  }
}
