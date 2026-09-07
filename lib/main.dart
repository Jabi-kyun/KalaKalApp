import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

  // OneSignal Setup
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID'] ?? '');
  OneSignal.Notifications.requestPermission(true);

  // Listen for Auth State Changes to Save OneSignal ID
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      final String? onesignalId = await OneSignal.User.pushSubscription.id;
      if (onesignalId != null) {
        print('🔥 ONESIGNAL ID SAVED: $onesignalId');
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'onesignalId': onesignalId,
        }, SetOptions(merge: true));
      }
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KalaKalApp',
      home: const SplashPage(),
    );
  }
}
