# DRFT Example

This example demonstrates how to use DRFT (Dart Resource Framework Toolkit) to manage infrastructure declaratively using Dart code.

## What This Example Shows

1. **Defining Resources**: Creating custom resource types (WebServer, Database, LoadBalancer)
2. **Resource Dependencies**: Setting up dependencies between resources
3. **Creating a Stack**: Organizing resources into a stack
4. **Planning Changes**: Generating a plan that shows what will be created/updated/deleted
5. **Dependency Resolution**: Demonstrating how DRFT automatically orders operations based on dependencies
6. **Applying Changes**: Executing the plan to create/update/delete resources
7. **State Management**: Showing how state is persisted and tracked

## Usage

### Option 1: Using the CLI (Recommended)

The example includes a `tool/drft_stack.dart` file that follows the Grinder-style pattern.
It imports the stack definition from `lib/drft_stack.dart`.

The CLI looks for `drft_stack.dart` in the current directory (or `tool/drft_stack.dart`, `lib/drft_stack.dart`).

```bash
# Show what changes would be made
dart run ../packages/drft_cli/bin/drft.dart plan

# Or specify the stack file explicitly
dart run ../packages/drft_cli/bin/drft.dart plan --stack-file tool/drft_stack.dart

# Apply the changes (will prompt for confirmation)
dart run ../packages/drft_cli/bin/drft.dart apply

# Apply without confirmation
dart run ../packages/drft_cli/bin/drft.dart apply --auto-approve

# Show detailed plan information (verbose mode)
dart run tool/drft_stack.dart plan --verbose

# Destroy all resources
dart run ../packages/drft_cli/bin/drft.dart destroy

# Refresh state from actual infrastructure
dart run tool/drft_stack.dart refresh

# You can also run the stack file directly (Grinder-style)
dart run tool/drft_stack.dart plan
dart run tool/drft_stack.dart plan --verbose
dart run tool/drft_stack.dart apply
dart run tool/drft_stack.dart apply --auto-approve
dart run tool/drft_stack.dart plan --json
```

### Option 2: Using the Programmatic API

Run the example directly:

```bash
dart pub get
dart run lib/main.dart
```

## Example Output

The example creates a simple infrastructure setup:
- A PostgreSQL database (`db.main`)
- Two web servers (`web.server1`, `web.server2`) that depend on the database
- A load balancer (`lb.main`) that depends on both web servers
- An App Store Bundle ID (`bundle.myapp`) with a read-only property
- A Provisioning Profile (`profile.main`) that depends on the Bundle ID's read-only property (using `DependentResource`)

The output shows:
- Resources being created
- The plan showing what operations will be performed
- Operation order demonstrating dependency resolution (database first, then web servers, then load balancer)
- Successful execution
- Final state showing all created resources

## Key Concepts Demonstrated

### Resource Definition

Resources are defined as immutable classes extending `Resource`:

```dart
class WebServer extends Resource {
  final String hostname;
  final int port;
  
  const WebServer({
    required String id,
    required this.hostname,
    this.port = 8080,
    List<Resource> dependencies = const [],
  }) : super(id: id, dependencies: dependencies);
}
```

### Dependency Management

Dependencies are specified explicitly using Resource references:

```dart
final database = Database(
  id: 'db.main',
  name: 'main_database',
  engine: 'postgresql',
);

final webServer = WebServer(
  id: 'web.server1',
  hostname: 'server1.example.com',
  dependencies: [database], // Depends on database (Resource reference)
);
```

DRFT automatically:
- Orders operations so dependencies are created first
- Detects circular dependencies
- Orders deletions in reverse (dependents deleted before dependencies)

### Stack Definition for CLI (Grinder-style)

For CLI usage, create a `tool/drft_stack.dart` file that:
1. Imports `drft_cli` and your stack definition
2. Has a `main()` function that calls `setStack()` and `drft(args)`

The stack definition should be in `lib/drft_stack.dart`:

```dart
// lib/drft_stack.dart
import 'package:drft/drft.dart';

DrftStack createStack({String? stateFilePath}) {
  return DrftStack(
    name: 'my-stack',
    providers: [MockProvider()],
    resources: [
      // Your resources here
    ],
    stateManager: StateManager(
      stateFilePath: stateFilePath ?? '.drft/state.json',
    ),
  );
}
```

```dart
// tool/drft_stack.dart
import 'package:drft_cli/drft_cli.dart';
import '../lib/drft_stack.dart' as stack;

void main(List<String> args) {
  setStack(stack.createStack());
  drft(args);
}
```

The CLI will execute `tool/drft_stack.dart` and pass the command arguments to `drft()`.

### Stack and Planning (Programmatic API)

```dart
final stack = DrftStack(
  name: 'example-stack',
  providers: [MockProvider()],
  resources: resources,
);

final plan = await stack.plan();
await stack.apply(plan);
```

## Files

- `tool/drft_stack.dart` - CLI entry point (Grinder-style, calls `drft()` from `main()`)
- `lib/drft_stack.dart` - Stack definition (defines resources and `createStack()` function)
- `lib/main.dart` - Programmatic API example (uses `lib/drft_stack.dart`)
- `.drft/example-state.json` - DRFT state file (created after first run)
- `.drft/mock-provider-state.json` - Mock provider state file (created after first run)

## Next Steps

- Try modifying resources in `drft_stack.dart` and running `plan` again to see update operations
- Add more resources with different dependency patterns
- Experiment with removing resources to see delete operations
- Check the `.drft/example-state.json` file to see how state is persisted
