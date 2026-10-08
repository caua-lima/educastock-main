import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart' as base;

class DefaultFirebaseOptionsDev {
  static FirebaseOptions get currentPlatform => base.DefaultFirebaseOptions.currentPlatform;
}
