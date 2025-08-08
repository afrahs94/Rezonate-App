// File: lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isIOS) return ios;
    if (Platform.isAndroid) return android;
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB7HAn6KWUs1aRtYSd_CCzjdBBSheBIgoQ',
    appId: '1:590573774973:android:d8878b595cd26f075aa914',
    messagingSenderId: '590573774973',
    projectId: 'rezonate-app-ce99b',
    storageBucket: 'rezonate-app-ce99b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAAstDRtjcisvhuauOPmf08nHeaNiyhErM',
    appId: '1:590573774973:ios:da18731cfa61df9b5aa914',
    messagingSenderId: '590573774973',
    projectId: 'rezonate-app-ce99b',
    storageBucket: 'rezonate-app-ce99b.firebasestorage.app',
    iosBundleId: 'com.example.newRezonate',
  );

}