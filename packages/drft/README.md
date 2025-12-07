# DRFT - Core Package

This is the core package for DRFT (Dart Resource Framework Toolkit).

## Overview

DRFT is an infrastructure-as-code toolkit written in Dart. This core package provides:

- Resource definitions
- Provider interface
- State management
- Planning and execution
- Mock provider for testing

## Installation

```yaml
dependencies:
  drft: ^0.1.0
```

## Usage

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
  
  final plan = await stack.plan();
  print(plan.summary);
  
  final result = await stack.apply(plan);
  print(result.summary);
}
```

## Development

This package is part of the DRFT workspace. See the root README for development instructions.

