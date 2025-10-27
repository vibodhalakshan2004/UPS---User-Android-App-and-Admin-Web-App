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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAN1Hv5Qr4_LIY4BGevFgGamQTAdQfcZuk',
    appId: '1:36064760029:web:efba54bf6eaf65abfecb34',
    messagingSenderId: '36064760029',
    projectId: 'ups-app-7d001',
    authDomain: 'ups-app-7d001.firebaseapp.com',
    storageBucket: 'ups-app-7d001.firebasestorage.app',
    measurementId: 'G-80P4E3VHGL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBnVn3OPoSXKbPNQLEGhCP5iTnMaVcDG28',
    appId: '1:36064760029:android:86855c4e2aba92aefecb34',
    messagingSenderId: '36064760029',
    projectId: 'ups-app-7d001',
    storageBucket: 'ups-app-7d001.firebasestorage.app',
  );
}
