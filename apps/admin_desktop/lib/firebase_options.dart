// Generated configuration for the UPS Admin Desktop app.
// This file is adapted from the FlutterFire configuration used in the mobile/web apps.
// Windows builds reuse the web configuration because Firebase does not yet provide
// distinct desktop credentials for this project. Update via FlutterFire CLI once
// Windows support is available in your Firebase project.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DesktopFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return web; // Reuse web credentials for desktop build.
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseOptions not configured for this platform. Run the FlutterFire CLI to configure.',
        );
      default:
        throw UnsupportedError('Unsupported platform for Firebase initialization.');
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _require(_webApiKey, 'ADMIN_DESKTOP_FIREBASE_WEB_API_KEY'),
        appId: _require(_webAppId, 'ADMIN_DESKTOP_FIREBASE_WEB_APP_ID'),
        messagingSenderId:
            _require(_messagingSenderId, 'ADMIN_DESKTOP_FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _require(_projectId, 'ADMIN_DESKTOP_FIREBASE_PROJECT_ID'),
        authDomain: _require(_webAuthDomain, 'ADMIN_DESKTOP_FIREBASE_WEB_AUTH_DOMAIN'),
        storageBucket: _require(_storageBucket, 'ADMIN_DESKTOP_FIREBASE_STORAGE_BUCKET'),
        measurementId:
            _optional(_webMeasurementId, 'ADMIN_DESKTOP_FIREBASE_WEB_MEASUREMENT_ID'),
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _require(_androidApiKey, 'ADMIN_DESKTOP_FIREBASE_ANDROID_API_KEY'),
        appId: _require(_androidAppId, 'ADMIN_DESKTOP_FIREBASE_ANDROID_APP_ID'),
        messagingSenderId:
            _require(_messagingSenderId, 'ADMIN_DESKTOP_FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _require(_projectId, 'ADMIN_DESKTOP_FIREBASE_PROJECT_ID'),
        storageBucket: _require(_storageBucket, 'ADMIN_DESKTOP_FIREBASE_STORAGE_BUCKET'),
      );

  static const String _projectId =
      String.fromEnvironment('ADMIN_DESKTOP_FIREBASE_PROJECT_ID', defaultValue: '');
  static const String _storageBucket =
      String.fromEnvironment('ADMIN_DESKTOP_FIREBASE_STORAGE_BUCKET', defaultValue: '');
  static const String _messagingSenderId =
      String.fromEnvironment('ADMIN_DESKTOP_FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');

  static const String _webApiKey =
      String.fromEnvironment('ADMIN_DESKTOP_FIREBASE_WEB_API_KEY', defaultValue: '');
  static const String _webAppId =
      String.fromEnvironment('ADMIN_DESKTOP_FIREBASE_WEB_APP_ID', defaultValue: '');
  static const String _webAuthDomain =
      String.fromEnvironment('ADMIN_DESKTOP_FIREBASE_WEB_AUTH_DOMAIN', defaultValue: '');
  static const String _webMeasurementId =
      String.fromEnvironment('ADMIN_DESKTOP_FIREBASE_WEB_MEASUREMENT_ID', defaultValue: '');

  static const String _androidApiKey =
      String.fromEnvironment('ADMIN_DESKTOP_FIREBASE_ANDROID_API_KEY', defaultValue: '');
  static const String _androidAppId =
      String.fromEnvironment('ADMIN_DESKTOP_FIREBASE_ANDROID_APP_ID', defaultValue: '');

  static String _require(String value, String name) {
    if (value.isEmpty) {
      throw StateError('Missing Firebase configuration for $name. '
          'Provide it with --dart-define or --dart-define-from-file.');
    }
    return value;
  }

  static String? _optional(String value, String _) {
    if (value.isEmpty) {
      return null;
    }
    return value;
  }
}
