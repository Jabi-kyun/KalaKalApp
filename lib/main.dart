import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ NEW
import 'screens/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ 1. Load the .env file BEFORE initializing Firebase or OneSignal
  await dotenv.load(fileName: ".env"); 

  await Firebase.initializeApp();

  // ✅ 2. Read the OneSignal App ID securely from .env
  final String oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  
  // Safety check: App will throw a clear error if the key is missing
  if (oneSignalAppId.isEmpty) {
    throw Exception("❌ ONESIGNAL_APP_ID is missing from your .env file!");
  }

  // ✅ 3. Initialize OneSignal using the secure variable
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(oneSignalAppId); 
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