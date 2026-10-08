import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart' as base;

class DefaultFirebaseOptionsProd {
  static FirebaseOptions get currentPlatform => base.DefaultFirebaseOptions.currentPlatform;
}
