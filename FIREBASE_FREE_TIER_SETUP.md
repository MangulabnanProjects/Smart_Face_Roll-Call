# Firebase FREE Tier Setup (No Billing Required!)

## 🎯 What You Can Use for FREE

✅ **Firebase Authentication** - Unlimited users, completely FREE  
❌ **Firestore Database** - Requires billing  
❌ **Firebase Storage** - Requires billing  

## 💡 Solution: Local Storage + Free Auth

Your app will work like this:
- **Admin Login**: Firebase Authentication (FREE)
- **Image Storage**: Local device storage (FREE)
- **Data**: Local storage with `shared_preferences` (FREE)

## Step-by-Step Setup (FREE Tier)

### Step 1: Enable Authentication Only

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **audioanalysisdb**
3. Click **Authentication** from left menu
4. Click **"Get started"**
5. Go to **"Sign-in method"** tab
6. Click **"Email/Password"**
7. Toggle **Enable** to ON
8. Click **"Save"**

✅ **Done!** This is 100% free, no billing required.

### Step 2: You Already Have Web Config! ✅

Perfect! I see you already updated `web/index.html` with your Firebase config:
```javascript
projectId: "audioanalysisdb"
```

### Step 3: Download Android & iOS Config (Optional)

Only if you want to test on mobile devices:

**For Android:**
1. Firebase Console → **Project Settings**
2. Scroll to "Your apps"
3. Click **Android icon**
4. Package name: `com.attendance.attendance_app`
5. Download `google-services.json`
6. Place in: `android/app/`

**For iOS:**
1. Same page, click **iOS icon**
2. Bundle ID: `com.attendance.attendanceApp`
3. Download `GoogleService-Info.plist`
4. Place in: `ios/Runner/`

### Step 4: Update Your Code

**Uncomment Firebase Auth in `pubspec.yaml`:**
```yaml
# Firebase for auth (FREE - no billing required!)
firebase_core: ^2.24.2
firebase_auth: ^4.15.3
```

Then run:
```bash
flutter pub get
```

**Update `lib/shared/services/auth_service.dart`:**

Replace the entire file with this simplified version:

```dart
import 'package:firebase_auth/firebase_auth.dart';

/// Authentication service for admin login/signup (FREE TIER)
/// Uses only Firebase Auth - no Firestore needed
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email and password
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(name);
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Check if user is admin (simplified - all logged in users are admin)
  Future<bool> isAdmin() async {
    return currentUser != null;
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
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
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      default:
        return e.message ?? 'Authentication error occurred';
    }
  }
}
```

**Update `lib/main.dart`:**

Uncomment Firebase init:
```dart
import 'package:firebase_core/firebase_core.dart';  // Uncomment

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();  // Uncomment
  
  runApp(const MyApp());
}
```

### Step 5: How Images Will Work (No Storage Needed)

Since you can't use Firebase Storage, images will be stored **locally on the device**:

**Mobile App:**
- Captured images → Saved to device storage
- View gallery → From device storage
- No cloud sync (all local)

**Future Option (When You Have Billing):**
- Can add Firebase Storage later
- Images will sync to cloud automatically

For now, images stay on the device only.

## 🚀 Run Your App!

```bash
cd d:/FacialRecognitionForAutomaticAttendance
flutter pub get
flutter run -d chrome
```

## ✅ What Works With This Setup

✅ Admin login/signup (web + mobile)  
✅ Password reset via email  
✅ User authentication state  
✅ Camera image capture (local only)  
✅ Gallery view (local images)  
✅ Web dashboard  
✅ All UI features  

❌ **Doesn't work:** Cloud image sync (requires Storage with billing)

## 💰 Cost: $0.00

Everything above is **100% FREE**:
- Firebase Auth: FREE unlimited
- Local storage: FREE
- All Flutter features: FREE

## 🔮 Future: When You Get Billing

When you're ready to enable billing later:
1. Add back `firebase_storage` and `cloud_firestore` to `pubspec.yaml`
2. Update code to sync images to cloud
3. Enable Firestore and Storage in Firebase Console

But for now, you can build and test everything locally!
