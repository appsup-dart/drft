/// DRFT function - Similar to Grinder's grind() function
///
/// This function is called from the stack file (like drft_stack.dart)
/// and parses arguments to execute the appropriate command.
///
/// Usage in drft_stack.dart:
/// ```dart
/// import 'package:drft_cli/drft_cli.dart';
///
/// void main(List<String> args) {
///   drft(args);
/// }
/// ```
library;

import 'dart:io';

import 'package:drft/drft.dart';

import 'commands/apply_command.dart';
import 'commands/destroy_command.dart';
import 'commands/plan_command.dart';
import 'commands/refresh_command.dart';

/// Global stack variable - set by the stack file
DrftStack? _globalStack;

/// Set the stack for drft() to use
void setStack(DrftStack stack) {
  _globalStack = stack;
}

/// Get the current stack
DrftStack? getStack() {
  return _globalStack;
}

/// Main DRFT function - called from stack files
///
/// This is similar to Grinder's grind() function.
/// The stack file should:
/// 1. Define a DrftStack
/// 2. Call setStack(stack) to register it
/// 3. Call drft(args) from main()
///
/// Example:
/// ```dart
/// import 'package:drft/drft.dart';
/// import 'package:drft_cli/drft_cli.dart';
///
/// DrftStack createStack() {
///   return DrftStack(
///     name: 'my-stack',
///     providers: [MockProvider()],
///     resources: [...],
///   );
/// }
///
/// void main(List<String> args) {
///   setStack(createStack());
///   drft(args);
/// }
/// ```
Future<void> drft(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exit(1);
  }

  final commandStr = args[0].toLowerCase();
  final commandArgs = args.skip(1).toList();
  
  // Check if verbose mode is enabled (check both command args and all args)
  final verbose = args.contains('--verbose') || args.contains('-v');

  final stack = _globalStack;
  if (stack == null) {
    stderr.writeln(
      'Error: No stack defined. Call setStack() before calling drft().',
    );
    exit(1);
  }

  try {
    int exitCode;
    switch (commandStr) {
      case 'plan':
        exitCode = await PlanCommand().run(
          stack: stack,
          args: commandArgs,
        );
        break;
      case 'apply':
        exitCode = await ApplyCommand().run(
          stack: stack,
          args: commandArgs,
        );
        break;
      case 'destroy':
        exitCode = await DestroyCommand().run(
          stack: stack,
          args: commandArgs,
        );
        break;
      case 'refresh':
        exitCode = await RefreshCommand().run(
          stack: stack,
          args: commandArgs,
        );
        break;
      default:
        stderr.writeln('Unknown command: $commandStr');
        _printUsage();
        exit(1);
    }
    exit(exitCode);
  } catch (e, stackTrace) {
    stderr.writeln('Error: $e');
    if (verbose) {
      stderr.writeln('\nStack trace:');
      stderr.writeln(stackTrace);
    } else if (e is! FormatException) {
      stderr.writeln('Stack trace: $stackTrace');
    }
    exit(1);
  }
}

void _printUsage() {
  print('''
DRFT - Dart Resource Framework Toolkit

Usage: drft <command> [options]

Commands:
  plan      Show what changes would be made
  apply     Apply the planned changes
  destroy   Destroy all resources in the stack
  refresh   Refresh state from actual infrastructure

Command Options:
  plan:
    --json              Output plan as JSON
    --verbose, -v       Show detailed output and stack traces on errors

  apply:
    --auto-approve      Skip interactive approval
    --verbose, -v       Show detailed output and stack traces on errors

  destroy:
    --auto-approve      Skip interactive approval
    --verbose, -v       Show detailed output and stack traces on errors

  refresh:
    --verbose, -v       Show detailed output and stack traces on errors

Examples:
  drft plan
  drft plan --json
  drft apply
  drft apply --auto-approve
  drft refresh
  drft destroy
''');
}
