import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Authentication service using Firebase Auth (FREE)
/// Connected to your audioanalysisdb project
class AuthService {
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  bool _isInitialized = false;

  AuthService() {
    try {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      // Firebase not available
    }
  }

  User? get currentUser => _isInitialized ? _auth.currentUser : null;
  bool get isLoggedIn => _isInitialized ? _auth.currentUser != null : false;
  Stream<User?> get authStateChanges => _isInitialized 
      ? _auth.authStateChanges() 
      : Stream.value(null);

  /// Sign up with email and password
  /// Also saves instructor details to Firestore 'Instructor_Information'
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String instructorCode,
  }) async {
    if (!_isInitialized) {
      throw 'Firebase not initialized. Please check your configuration.';
    }
    
    try {
      // 1. Create Auth User
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // 2. Update display name with full name
      final fullName = '$firstName $lastName';
      await userCredential.user?.updateDisplayName(fullName);

      // 3. Save to Firestore "Instructor_Information"
      // Note: Storing password in plain text is not recommended, but implementing as requested.
      await _firestore.collection('Instructor_Information').doc(userCredential.user!.uid).set({
        'Email': email,
        'First_Name': firstName,
        'Last_Name': lastName,
        'Full_Name': fullName,
        'Instructor_ID': instructorCode,
        'Password': password, 
      });
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw 'Database Locked: Please go to Firebase Console > Firestore > Rules and set to "allow read, write: if true;"';
      }
      throw e.message ?? 'Unknown Firebase Error';
    } catch (e) {
      throw e.toString();
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) {
      throw 'Firebase not initialized. Please check your configuration.';
    }
    
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in using Instructor ID (Retrieves credentials from Firestore)
  Future<UserCredential?> signInWithInstructorCode(String instructorCode) async {
    if (!_isInitialized) {
      throw 'Firebase not initialized. Please check your configuration.';
    }

    try {
      // 1. Query Firestore for the Instructor ID
      final querySnapshot = await _firestore
          .collection('Instructor_Information')
          .where('Instructor_ID', isEqualTo: instructorCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw 'Instructor ID not found.';
      }

      // 2. Get credentials from the document
      final data = querySnapshot.docs.first.data();
      final email = data['Email'] as String?;
      final password = data['Password'] as String?;

      if (email == null || password == null) {
        throw 'Instructor record exists but is missing credentials.';
      }

      // 3. Sign in using the retrieved credentials
      return await signIn(email: email, password: password);
      
    } on FirebaseException catch (e) {
       if (e.code == 'permission-denied') {
        throw 'Database Locked: Please enable "read" permission in Firebase Console Rules.';
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (_isInitialized) {
      await _auth.signOut();
    }
  }

  /// Check if user is admin
  Future<bool> isAdmin() async {
    return _isInitialized && currentUser != null;
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    if (!_isInitialized) {
      throw 'Firebase not initialized. Please check your configuration.';
    }
    
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak (min 6 characters)';
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'user-not-found':
        return 'No user found for that email';
      case 'wrong-password':
        return 'Wrong password provided';
      default:
        return 'An undefined error happened.';
    }
  }
}
