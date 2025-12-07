/// Example DRFT application
///
/// This example demonstrates how to use DRFT to manage infrastructure
/// declaratively using Dart code.
///
/// This file shows the programmatic API usage.
/// For CLI usage, see tool/drft_stack.dart.
// ignore_for_file: avoid_print

library;

import 'dart:io';

import 'drft_stack.dart' as stack_file;

Future<void> main() async {
  print('🚀 DRFT Example Application\n');
  print('This example demonstrates the programmatic API.\n');
  print('To use the CLI instead, run:');
  print('  dart run ../packages/drft_cli/bin/drft.dart plan');
  print('  dart run ../packages/drft_cli/bin/drft.dart apply\n');

  // Create stack using the same definition as CLI
  final stack = stack_file.createStack(
    stateFilePath: '.drft/example-state.json',
  );

  await stack.refresh();

  print('📦 Stack: ${stack.name}');
  print('   Resources: ${stack.resources.length}\n');

  // Create a plan
  print('📋 Creating plan...');
  final plan = await stack.plan();
  print(plan.summary);

  // Show operation order (demonstrates dependency resolution)
  print('📊 Operation order (showing dependency resolution):');
  for (var i = 0; i < plan.operations.length; i++) {
    final op = plan.operations[i];
    final resourceId =
        op.resource?.id ?? op.currentState?.resourceId ?? 'unknown';
    print('   ${i + 1}. ${op.type.name.toUpperCase()}: $resourceId');
  }
  print('');

  // Apply the plan
  print('⚙️  Applying plan...');
  final result = await stack.apply(plan);
  print(result.summary);

  if (result.success) {
    print('✅ All operations completed successfully!\n');

    // Show final state
    print('📊 Final state:');
    final finalState = await stack.stateManager.load();
    print('   Stack: ${finalState.stackName}');
    print('   Resources: ${finalState.resources.length}');
    for (final resourceState in finalState.resources.values) {
      print(
        '     - ${resourceState.resourceId} (${resourceState.runtimeType})',
      );
    }
  } else {
    print('❌ Some operations failed\n');
    for (final opResult in result.operations) {
      if (!opResult.success) {
        print('   Failed: ${opResult.operation.type.name} - ${opResult.error}');
      }
    }
    exit(1);
  }
}
