// File generated manually to bypass CLI issues.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase App.
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
    // ignore: missing_enum_constant_in_switch
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyAnlrlVM5VTMvkhwgpSYiciFBd2Zd-FWGw",
    authDomain: "audioanalysisdb.firebaseapp.com",
    projectId: "audioanalysisdb",
    storageBucket: "audioanalysisdb.firebasestorage.app",
    messagingSenderId: "911226358765",
    appId: "1:911226358765:web:04905ffc247c930e9275e4",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAz9n-GY50wDQIPXFgDNh2svFAQg8-v9zY',
    appId: '1:911226358765:android:8792f53d09dafea39275e4',
    messagingSenderId: '911226358765',
    projectId: 'audioanalysisdb',
    storageBucket: 'audioanalysisdb.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD0A18opYmFAppdthqkiZ_k6m4rIEbsnck',
    appId: '1:911226358765:ios:da431ad67074d1bf9275e4',
    messagingSenderId: '911226358765',
    projectId: 'audioanalysisdb',
    storageBucket: 'audioanalysisdb.firebasestorage.app',
    iosClientId: '1:911226358765:ios:da431ad67074d1bf9275e4',
    iosBundleId: 'com.attendance.attendanceApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'PASTE_YOUR_MACOS_API_KEY_HERE',
    appId: 'PASTE_YOUR_MACOS_APP_ID_HERE',
    messagingSenderId: 'PASTE_YOUR_SENDER_ID_HERE',
    projectId: 'audioanalysisdb',
    storageBucket: 'audioanalysisdb.appspot.com',
    iosClientId: 'PASTE_YOUR_MACOS_CLIENT_ID_HERE',
    iosBundleId: 'com.example.attendanceApp',
  );
}
