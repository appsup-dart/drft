/// Refresh command - Refresh state from actual infrastructure
library;

import 'dart:io';

import 'package:drft/drft.dart';

/// Refresh command implementation
class RefreshCommand {
  Future<int> run({
    required DrftStack stack,
    required List<String> args,
  }) async {
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
    } catch (e) {
      stderr.writeln('Error refreshing state: $e');
      return 1;
    }
  }
}

