/// Main CLI entry point
library;

import 'dart:io';

import 'package:args/args.dart';

import 'stack_loader.dart';

/// DRFT CLI application
class DrftCli {
  final ArgParser parser;

  DrftCli() : parser = _buildParser();

  static ArgParser _buildParser() {
    final parser = ArgParser(allowTrailingOptions: true)
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show this help message',
      )
      ..addFlag(
        'version',
        negatable: false,
        help: 'Show version information',
      )
      ..addOption(
        'stack-file',
        abbr: 'f',
        defaultsTo: 'drft_stack.dart',
        help: 'Path to the stack definition file',
      );

    return parser;
  }

  /// Run the CLI with command-line arguments
  Future<int> run(List<String> args) async {
    try {
      // Parse only known options, allowing unknown options to pass through
      ArgResults results;
      try {
        results = parser.parse(args);
      } on FormatException {
        // If parsing fails due to unknown option, try to parse just the known options
        // and pass the rest through
        final knownOptions = <String>[];
        final rest = <String>[];
        
        for (var i = 0; i < args.length; i++) {
          final arg = args[i];
          if (arg == '--help' || arg == '-h') {
            _printUsage();
            return 0;
          } else if (arg == '--version') {
            _printVersion();
            return 0;
          } else if (arg == '--stack-file' || arg == '-f') {
            knownOptions.add(arg);
            if (i + 1 < args.length) {
              knownOptions.add(args[i + 1]);
              i++;
            }
          } else if (arg.startsWith('--stack-file=') || arg.startsWith('-f=')) {
            knownOptions.add(arg);
          } else if (!arg.startsWith('-')) {
            // First non-option is the command, everything after goes to rest
            rest.addAll(args.sublist(i));
            break;
          } else {
            // Unknown option - pass to rest
            rest.addAll(args.sublist(i));
            break;
          }
        }
        
        if (rest.isEmpty) {
          _printUsage();
          return 1;
        }
        
        final stackFile = knownOptions
            .where((a) => a.startsWith('--stack-file=') || a.startsWith('-f='))
            .map((a) => a.split('=')[1])
            .firstOrNull ??
            (knownOptions.contains('--stack-file') || knownOptions.contains('-f')
                ? knownOptions[knownOptions.indexOf('--stack-file') + 1]
                : 'drft_stack.dart');
        
        return await StackLoader.executeStackFile(
          stackFile: stackFile,
          args: rest,
        );
      }

      if (results['help'] == true) {
        _printUsage();
        return 0;
      }

      if (results['version'] == true) {
        _printVersion();
        return 0;
      }

      if (results.rest.isEmpty) {
        _printUsage();
        return 1;
      }

      final stackFile = results['stack-file'] as String;
      final commandArgs = results.rest;

      // Execute the stack file with the command arguments
      // The stack file should call drft() with the arguments
      return await StackLoader.executeStackFile(
        stackFile: stackFile,
        args: commandArgs,
      );
    } catch (e, stackTrace) {
      stderr.writeln('Error: $e');
      if (e is! FormatException) {
        stderr.writeln('Stack trace: $stackTrace');
      }
      return 1;
    }
  }

  void _printUsage() {
    print('''
DRFT - Dart Resource Framework Toolkit

Usage: drft [options] <command> [command-options]

Commands:
  plan      Show what changes would be made
  apply     Apply the planned changes
  destroy   Destroy all resources in the stack
  refresh   Refresh state from actual infrastructure

Options:
${parser.usage}

Examples:
  drft plan
  drft --stack-file my_stack.dart plan
  drft apply
  drft apply --auto-approve
  drft refresh
  drft destroy
''');
  }

  void _printVersion() {
    print('DRFT CLI version 0.1.0');
  }
}

/// Main entry point
Future<void> main(List<String> args) async {
  final cli = DrftCli();
  final exitCode = await cli.run(args);
  exit(exitCode);
}
