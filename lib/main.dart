import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'shared/screens/login_screen.dart';
import 'mobile/screens/main_screen.dart';
import 'mobile/screens/camera_screen.dart';
import 'mobile/screens/gallery_screen.dart';
import 'mobile/screens/student_login_screen.dart';
import 'mobile/screens/student_signup_screen.dart';
import 'web/screens/dashboard_screen.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    // Firebase failed - app will run without it
    debugPrint('⚠️ Firebase initialization failed: $e');
    debugPrint('App will continue without Firebase features');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Use home instead of initialRoute handles the default '/' path better on web
      home: kIsWeb ? const LoginScreen() : const MobileStudentLoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(), // Web instructor login
        '/student-login': (context) => const MobileStudentLoginScreen(), // Mobile student login
        '/student-signup': (context) => const MobileStudentSignupScreen(), // Mobile student signup
        '/home': (context) => kIsWeb ? const WebDashboardScreen() : const MobileMainScreen(),
        '/camera': (context) => const CameraScreen(),
        '/gallery': (context) => const GalleryScreen(),
        '/dashboard': (context) => const WebDashboardScreen(),
      },
    );
  }
}
