/// DRFT Stack Definition
///
/// This file contains the stack definition used by both:
/// - The CLI entry point (tool/drft_stack.dart)
/// - The programmatic API example (lib/main.dart)
library;

import 'package:drft/drft.dart';
import 'package:drft_firebase/drft_firebase.dart';

import 'mock_resources.dart';

/// Create and return the stack
///
/// [stateFilePath] is optional and only used by the programmatic API.
/// The CLI uses the default path.
DrftStack createStack({String? stateFilePath}) {
  // Create resources
  final database = const Database(
    id: 'db.main',
    name: 'main_database',
    engine: 'postgresql',
    port: 5432,
  );

  final webServer1 = WebServer(
    id: 'web.server1',
    hostname: 'server1.example.com',
    port: 8080,
    environment: 'production',
    dependencies: [database],
  );

  final webServer2 = WebServer(
    id: 'web.server2',
    hostname: 'server2.example.com',
    port: 8080,
    environment: 'production',
    dependencies: [database],
  );

  final loadBalancer = LoadBalancer(
    id: 'lb.main',
    backendServers: const ['web.server1', 'web.server2'],
    port: 80,
    dependencies: [webServer1, webServer2],
  );

  // Example of DependentResource: App Store Bundle ID and Provisioning Profile
  // The Bundle ID gets an ID assigned by the provider (read-only property)
  final bundleId = const AppStoreBundleId(
    id: 'bundle.myapp',
    name: 'com.example.myapp',
    platform: 'ios',
  );

  // The Provisioning Profile needs the bundle ID that was assigned by App Store
  // Since this is a read-only property, we use DependentResource
  // Using the .single() constructor for easier access to the dependency state
  final provisioningProfile = DependentResource.single(
    id: 'profile.main',
    dependency: bundleId,
    builder: (bundleIdState) {
      // Extract the read-only property using the typed getter
      // The MockProvider simulates App Store by adding 'bundleId' to properties
      // In a real App Store provider, this would come from the actual API response
      final bundleIdValue = bundleIdState.bundleId;

      // Build the actual ProvisioningProfile resource
      return ProvisioningProfile(
        id: 'profile.main',
        bundleId: bundleIdValue,
        type: 'development',
        certificates: const ['cert1', 'cert2'],
      );
    },
  );

  // Firebase resources example
  // Note: Firebase project creation/deletion is not supported via API
  // These resources will only work for reading existing projects/apps
  final firebaseProject = const FirebaseProject(
    id: 'firebase.project1',
    projectId: 'appsup-test',
    displayName: 'Example Firebase Project',
  );

  final firebaseIosApp = FirebaseApp(
    id: 'firebase.app.ios',
    projectId: firebaseProject.projectId,
    platform: FirebaseAppPlatform.ios,
    displayName: 'Example iOS App',
    bundleId: 'com.example.myapp',
  );

  final firebaseAndroidApp = FirebaseApp(
    id: 'firebase.app.android',
    projectId: firebaseProject.projectId,
    platform: FirebaseAppPlatform.android,
    displayName: 'Example Android App',
    packageName: 'com.example.myapp',
  );

  final firebaseWebApp = FirebaseApp(
    id: 'firebase.app.web',
    projectId: firebaseProject.projectId,
    platform: FirebaseAppPlatform.web,
    displayName: 'Example Web App',
  );

  final resources = [
    database,
    webServer1,
    webServer2,
    loadBalancer,
    bundleId,
    provisioningProfile,
    firebaseProject,
    firebaseIosApp,
    firebaseAndroidApp,
    firebaseWebApp,
  ];

  // Create stack
  return DrftStack(
    name: 'example-stack',
    providers: [
      FirebaseProvider(),
      MockProvider(
        storagePath: '.drft/mock-provider-state.json',
      ),
    ],
    resources: resources,
    stateManager: StateManager(
      stateFilePath: stateFilePath ?? '.drft/example-state.json',
    ),
  );
}
