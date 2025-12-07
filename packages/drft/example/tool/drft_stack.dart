/// DRFT Stack CLI Entry Point
///
/// This file is executed by the DRFT CLI (similar to tool/grind.dart in Grinder).
/// It imports the stack definition from lib/drft_stack.dart and calls drft().
///
/// Usage:
///   dart run ../packages/drft_cli/bin/drft.dart plan
///   dart run ../packages/drft_cli/bin/drft.dart apply
///   dart run tool/drft_stack.dart plan  (if run directly)
library;
import 'package:drft_cli/drft_cli.dart';

import 'package:drft_example/drft_stack.dart' as stack;

/// Main entry point - called by the CLI
void main(List<String> args) {
  // Create and register the stack
  setStack(stack.createStack());

  // Call drft() with the command arguments
  drft(args);
}
