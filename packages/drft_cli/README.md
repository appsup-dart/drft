# DRFT CLI

Command-line interface for DRFT (Dart Resource Framework Toolkit).

## Installation

```bash
cd packages/drft_cli
dart pub get
```

## Usage

### Basic Commands

```bash
# Show what changes would be made
dart run bin/drft.dart plan

# Apply the planned changes
dart run bin/drft.dart apply

# Destroy all resources
dart run bin/drft.dart destroy
```

### Options

```bash
# Specify a custom stack file
dart run bin/drft.dart plan --stack-file my_stack.dart

# Specify a custom state file
dart run bin/drft.dart plan --state-file .drft/custom-state.json

# Auto-approve apply (skip confirmation)
dart run bin/drft.dart apply --auto-approve

# Output plan as JSON
dart run bin/drft.dart plan --json
```

## Stack File Format

The CLI expects a Dart file that defines your infrastructure stack. For now, stack loading from files is not yet fully implemented. You can use the programmatic API directly (see `example/lib/main.dart` for reference).

Future versions will support:
- Loading stack definitions from Dart files
- YAML/JSON stack definitions
- Code generation for stack loaders

## Development

This package is part of the DRFT workspace. See the root README for development instructions.

