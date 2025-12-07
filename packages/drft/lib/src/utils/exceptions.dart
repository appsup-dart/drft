/// Common exceptions used throughout DRFT
library;

/// Base exception for DRFT errors
class DrftException implements Exception {
  final String message;
  final Object? cause;
  
  DrftException(this.message, [this.cause]);
  
  @override
  String toString() {
    if (cause != null) {
      return 'DrftException: $message\nCaused by: $cause';
    }
    return 'DrftException: $message';
  }
}

/// Exception thrown when validation fails
class ValidationException extends DrftException {
  ValidationException(super.message, [super.cause]);
}

/// Exception thrown when a resource is not found
class ResourceNotFoundException extends DrftException {
  ResourceNotFoundException(String resourceId)
      : super('Resource not found: $resourceId');
}

/// Exception thrown when a provider is not found
class ProviderNotFoundException extends DrftException {
  ProviderNotFoundException(String resourceType)
      : super('No provider found for resource type: $resourceType');
}

/// Exception thrown when state operations fail
class StateException extends DrftException {
  StateException(super.message, [super.cause]);
}

