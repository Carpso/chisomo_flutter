// Generated Firebase options for the Android app (firebase_core).
// Kept explicit so Firebase.initializeApp() always works regardless of how
// google-services.json is (or isn't) wired into the build.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Default Firebase configuration for Kingdom Sponsor (Android).
/// Values come from android/app/google-services.json (kingdom-sponsor project).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC1o9SgvAnAKWYESdg2FcSiQsu4a2QJMNY',
    appId: '1:252401896317:android:c84a47e69993f12896da14',
    messagingSenderId: '252401896317',
    projectId: 'kingdom-sponsor',
  );
}
