/// Plan command - Show what changes would be made
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:drft/drft.dart';
import 'package:drft/src/core/resource_serialization.dart';

/// Plan command implementation
class PlanCommand {
  Future<int> run({
    DrftStack? stack,
    required List<String> args,
  }) async {
    final parser = ArgParser()
      ..addFlag(
        'json',
        negatable: false,
        help: 'Output plan as JSON',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Show detailed information about resource changes',
      );

    final results = parser.parse(args);
    final verbose = results['verbose'] == true;

    try {
      if (stack == null) {
        stderr.writeln('Error: No stack provided');
        return 1;
      }

      // Create plan
      stdout.writeln('Creating plan...\n');
      final plan = await stack.plan(includeVerboseInfo: verbose);

      // Output plan
      if (results['json'] == true) {
        final json = plan.toJson();
        stdout.writeln(json);
      } else {
        _printPlan(plan, verbose: verbose);
      }

      return 0;
    } catch (e, stackTrace) {
      stderr.writeln('Error creating plan: $e');
      if (verbose) {
        stderr.writeln('\nStack trace:');
        stderr.writeln(stackTrace);
      }
      return 1;
    }
  }

  void _printPlan(Plan plan, {bool verbose = false}) {
    stdout.writeln(plan.summary);
    
    if (verbose) {
      _printVerbosePlan(plan);
    } else {
      stdout.writeln('Operations:');
      for (var i = 0; i < plan.operations.length; i++) {
        final op = plan.operations[i];
        final resourceId = op.resource?.id ?? op.currentState?.resourceId ?? 'unknown';
        final resourceType = op.resource?.runtimeType ??
            op.currentState?.resource.runtimeType ??
            'unknown';

        stdout.writeln(
          '  ${i + 1}. ${_formatOperationType(op.type)} $resourceId ($resourceType)',
        );
      }
    }
  }

  void _printVerbosePlan(Plan plan) {
    // Get verbose information from plan
    final verboseInfo = plan.verboseInfo;
    
    // Show unchanged resources
    if (verboseInfo.unchanged.isNotEmpty) {
      stdout.writeln('\n✅ Resources as expected (${verboseInfo.unchanged.length}):');
      for (final resourceId in verboseInfo.unchanged) {
        stdout.writeln('  • $resourceId');
      }
    }
    
    // Show resources to create
    final creates = plan.operations.where((op) => op.type == OperationType.create).toList();
    if (creates.isNotEmpty) {
      stdout.writeln('\n➕ Resources to create (${creates.length}):');
      for (var i = 0; i < creates.length; i++) {
        final op = creates[i];
        final resourceId = op.resource?.id ?? 'unknown';
        final resourceType = op.resource?.runtimeType ?? 'unknown';
        stdout.writeln('  ${i + 1}. $resourceId ($resourceType)');
        
        // Show properties that will be set
        if (op.resource != null) {
          final resourceJson = ResourceSerialization.toJson(op.resource!);
          // Properties are at top level in new format, filter out metadata
          final properties = <String, dynamic>{};
          for (final entry in resourceJson.entries) {
            if (entry.key != '.type' &&
                entry.key != 'id' &&
                entry.key != 'dependencies') {
              properties[entry.key] = entry.value;
            }
          }
          // Filter out closures/functions and other non-serializable values
          final displayableProperties = properties.entries
              .where((e) => !_isFunctionOrClosure(e.value))
              .toList();
          if (displayableProperties.isNotEmpty) {
            stdout.writeln('     Properties:');
            for (final entry in displayableProperties) {
              stdout.writeln('       • ${entry.key}: ${_formatValue(entry.value)}');
            }
          }
        }
      }
    }
    
    // Show resources to update
    final updates = plan.operations.where((op) => op.type == OperationType.update).toList();
    if (updates.isNotEmpty) {
      stdout.writeln('\n🔄 Resources to update (${updates.length}):');
      for (var i = 0; i < updates.length; i++) {
        final op = updates[i];
        final resourceId = op.resource?.id ?? op.currentState?.resourceId ?? 'unknown';
        final resourceType = op.resource?.runtimeType ??
            op.currentState?.resource.runtimeType ??
            'unknown';
        stdout.writeln('  ${i + 1}. $resourceId ($resourceType)');
        
        // Show differences
        if (op.resource != null && op.currentState != null) {
          final differences = verboseInfo.differences[resourceId];
          if (differences != null && differences.isNotEmpty) {
            stdout.writeln('     Changes:');
            for (final diff in differences) {
              stdout.writeln('       • ${diff.field}:');
              stdout.writeln('         - Current: ${_formatValue(diff.current)}');
              stdout.writeln('         + Desired: ${_formatValue(diff.desired)}');
            }
          }
        }
      }
    }
    
    // Show resources to delete
    final deletes = plan.operations.where((op) => op.type == OperationType.delete).toList();
    if (deletes.isNotEmpty) {
      stdout.writeln('\n➖ Resources to delete (${deletes.length}):');
      for (var i = 0; i < deletes.length; i++) {
        final op = deletes[i];
        final resourceId = op.currentState?.resourceId ?? 'unknown';
        final resourceType = op.currentState?.resource.runtimeType ?? 'unknown';
        stdout.writeln('  ${i + 1}. $resourceId ($resourceType)');
      }
    }
    
    if (plan.operations.isEmpty && verboseInfo.unchanged.isNotEmpty) {
      stdout.writeln('\n✨ No changes needed. All resources are up to date.');
    }
  }

  bool _isFunctionOrClosure(dynamic value) {
    // Check if value is a function or closure
    final str = value.toString();
    return str.contains('Closure') || 
           str.contains('Function') ||
           str.startsWith('() =>');
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return value;
    if (value is List) {
      if (value.isEmpty) return '[]';
      // For short lists, show inline; for longer lists, show one per line
      if (value.length <= 3) {
        return '[${value.map((e) => _formatValue(e)).join(', ')}]';
      } else {
        return '[\n${value.map((e) => '         ${_formatValue(e)}').join(',\n')}\n       ]';
      }
    }
    if (value is Map) {
      if (value.isEmpty) return '{}';
      // For maps, show one entry per line for readability
      final entries = value.entries.map((e) => '         ${e.key}: ${_formatValue(e.value)}').join(',\n');
      return '{\n$entries\n       }';
    }
    return value.toString();
  }

  String _formatOperationType(OperationType type) {
    switch (type) {
      case OperationType.create:
        return '+';
      case OperationType.update:
        return '~';
      case OperationType.delete:
        return '-';
    }
  }
}

