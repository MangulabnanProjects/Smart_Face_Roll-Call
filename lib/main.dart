import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    
    // Disable persistence as requested by user to prevent "flickering"
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  } catch (e) {
    debugPrint('⚠️ Firebase initialization failed: $e');
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
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(), 
        '/student-login': (context) => const MobileStudentLoginScreen(),
        '/student-signup': (context) => const MobileStudentSignupScreen(),
        '/home': (context) => kIsWeb ? const WebDashboardScreen() : const MobileMainScreen(),
        '/camera': (context) => const CameraScreen(),
        '/gallery': (context) => const GalleryScreen(),
        '/dashboard': (context) => const WebDashboardScreen(),
      },
    );
  }
}

/// Handles persistent login state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. User logged in
        if (snapshot.hasData) {
          return kIsWeb ? const WebDashboardScreen() : const MobileMainScreen();
        }

        // 3. User logged out
        return kIsWeb ? const LoginScreen() : const MobileStudentLoginScreen();
      },
    );
  }
}
