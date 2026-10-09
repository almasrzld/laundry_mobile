import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA2cByYKvI0vJXF_317LTtuSo3Kx_NWpHk',
    appId: '1:507959895142:web:1c280ae1fc1c7f558df9a7',
    messagingSenderId: '507959895142',
    projectId: 'laundry-app-4cdd5',
    authDomain: 'laundry-app-4cdd5.firebaseapp.com',
    storageBucket: 'laundry-app-4cdd5.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA2cByYKvI0vJXF_317LTtuSo3Kx_NWpHk',
    appId: '1:507959895142:android:1c280ae1fc1c7f558df9a7',
    messagingSenderId: '507959895142',
    projectId: 'laundry-app-4cdd5',
    storageBucket: 'laundry-app-4cdd5.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA2cByYKvI0vJXF_317LTtuSo3Kx_NWpHk',
    appId: '1:507959895142:ios:1c280ae1fc1c7f558df9a7',
    messagingSenderId: '507959895142',
    projectId: 'laundry-app-4cdd5',
    storageBucket: 'laundry-app-4cdd5.firebasestorage.app',
  );
}
