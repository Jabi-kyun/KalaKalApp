import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // ✅ NEW
import 'screens/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ Initialize OneSignal (Replace with your actual App ID from Phase 1)
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("PASTE_YOUR_ONESIGNAL_APP_ID_HERE"); 
  OneSignal.Notifications.requestPermission(true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KalaKalApp', 
      home: const LoginPage(),
    );
  }
}