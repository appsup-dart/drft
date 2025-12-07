/// Apply command - Apply the planned changes
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:drft/drft.dart';

/// Apply command implementation
class ApplyCommand {
  Future<int> run({
    DrftStack? stack,
    required List<String> args,
  }) async {
    final parser = ArgParser()
      ..addFlag(
        'auto-approve',
        negatable: false,
        help: 'Skip interactive approval',
      );

    final results = parser.parse(args);

    try {
      if (stack == null) {
        stderr.writeln('Error: No stack provided');
        return 1;
      }

      // Create plan
      stdout.writeln('Creating plan...\n');
      final plan = await stack.plan();

      // Show plan
      stdout.writeln(plan.summary);
      stdout.writeln('Operations:');
      for (var i = 0; i < plan.operations.length; i++) {
        final op = plan.operations[i];
        final resourceId = op.resource?.id ?? op.currentState?.resourceId ?? 'unknown';
        stdout.writeln('  ${i + 1}. ${op.type.name.toUpperCase()}: $resourceId');
      }
      stdout.writeln('');

      // Ask for approval unless auto-approve
      if (results['auto-approve'] != true) {
        stdout.write('Do you want to apply these changes? (yes/no): ');
        final input = stdin.readLineSync()?.toLowerCase();
        if (input != 'yes' && input != 'y') {
          stdout.writeln('Apply cancelled.');
          return 0;
        }
        stdout.writeln('');
      }

      // Apply plan
      stdout.writeln('Applying plan...\n');
      final result = await stack.apply(plan);

      // Show results
      stdout.writeln(result.summary);

      if (result.success) {
        stdout.writeln('✅ Apply completed successfully!');
        return 0;
      } else {
        stderr.writeln('❌ Apply failed!');
        for (final opResult in result.operations) {
          if (!opResult.success) {
            stderr.writeln('  Failed: ${opResult.operation.type.name} - ${opResult.error}');
          }
        }
        return 1;
      }
    } catch (e) {
      stderr.writeln('Error applying plan: $e');
      return 1;
    }
  }
}

