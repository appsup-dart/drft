# DRFT - Dart Resource Framework Toolkit

**DRFT** (pronounced "drift") is an infrastructure-as-code toolkit written in Dart. It allows you to describe your infrastructure declaratively using Dart code, leveraging Dart's expressive syntax and type system.

## Overview

DRFT enables you to:
- **Declare infrastructure** using clean, type-safe Dart code
- **Compare states** between desired and actual infrastructure
- **Plan changes** before applying them
- **Execute changes** to bring infrastructure to the desired state
- **Manage state** to track infrastructure resources

## Project Structure

This is a workspace containing multiple packages:

```
drft/
├── packages/
│   ├── drft/              # Core framework
│   ├── drft_firebase/      # Firebase provider
│   ├── drft_appstore/      # App Store Connect provider
│   └── drft_playstore/     # Google Play Console provider
├── docs/                   # Documentation
└── pubspec.yaml            # Workspace configuration
```

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/appsup-dart/drft.git
cd drft

# Get dependencies for all packages
dart pub get
```

### Example

```dart
import 'package:drft/drft.dart';

void main() async {
  final stack = DrftStack(
    name: 'my-infrastructure',
    providers: [
      MockProvider(), // For testing
    ],
    resources: [
      // Your resources here
    ],
  );

  // Plan changes
  final plan = await stack.plan();
  print(plan.summary);

  // Apply changes
  final result = await stack.apply(plan);
  print(result.summary);
}
```

## Development

### Workspace Setup

This project uses Dart workspace resolution. All packages are in the `packages/` directory and can reference each other using path dependencies.

### Running Tests

```bash
# Run tests for all packages
dart test

# Run tests for a specific package
cd packages/drft
dart test
```

### Building

```bash
# Build all packages
dart pub get
```

## Features

- **Type Safety**: Leverage Dart's strong typing for infrastructure definitions
- **Immutable Resources**: Flutter-style immutable resources with final properties
- **Clean Syntax**: Familiar Dart constructor syntax, just like Flutter widgets
- **State Management**: Automatic state tracking and comparison
- **Dependency Resolution**: Automatic handling of resource dependencies
- **Plan Before Apply**: Always see what will change before making changes
- **Extensible**: Easy to add new providers and resources
- **Idempotent**: Running the same configuration multiple times is safe

## Project Status

✅ **Phase 1 Complete** - Core framework is implemented and functional. Currently working on provider implementations.

## Documentation

- [Getting Started](./docs/getting-started.mdx) - Quick start guide
- [Core Concepts](./docs/concepts.mdx) - Understanding DRFT fundamentals
- [Architecture](./docs/architecture.mdx) - System design and components
- [Resource, ResourceState, and Provider Relationship](./docs/resource-state-provider-relationship.mdx) - Core concepts and their relationships
- [Provider Development](./docs/providers.mdx) - Creating custom providers
- [Resource Development](./docs/resources.mdx) - Creating custom resources
- [Examples](./docs/examples.mdx) - Example configurations
- [Firebase Provider](./docs/firebase-provider.mdx) - Firebase configuration guide
- [App Store Provider](./docs/appstore-provider.mdx) - App Store Connect guide

For full documentation, visit [docs.page](https://docs.page/appsup-dart/drft)

## License

This project is licensed under the BSD-3-Clause License. See the [LICENSE](./LICENSE) file for details.
