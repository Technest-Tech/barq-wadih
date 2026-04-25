// File generated from Firebase config files.
// Do NOT commit sensitive keys to public repos.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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
    apiKey: 'AIzaSyC4o2_8_-nvq_mhB1fUDV25M8cFUY8IrVA',
    authDomain: 'barqwadih-40271.firebaseapp.com',
    projectId: 'barqwadih-40271',
    storageBucket: 'barqwadih-40271.firebasestorage.app',
    messagingSenderId: '816087371543',
    appId: '1:816087371543:web:ae264e2a5c776e1363f152',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDfuGij59wDanCHNzXklWA1a80L1RQ_lOs',
    appId: '1:816087371543:android:c1521d394de014d263f152',
    messagingSenderId: '816087371543',
    projectId: 'barqwadih-40271',
    storageBucket: 'barqwadih-40271.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAqTTZ1TiXjHM8JTd3oMctXuO99E7VtzuQ',
    appId: '1:816087371543:ios:6a77540bec50cac463f152',
    messagingSenderId: '816087371543',
    projectId: 'barqwadih-40271',
    storageBucket: 'barqwadih-40271.firebasestorage.app',
    iosBundleId: 'com.barqwadih.app',
  );
}
