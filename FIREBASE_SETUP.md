# Firebase Setup Guide - Step by Step

## 📋 Overview
You mentioned you already have a Firebase project. Here's how to download the configuration files and set up your Flutter app.

## Step 1: Access Your Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click on your existing project
3. You should see the project overview page

## Step 2: Download Android Configuration

### In Firebase Console:
1. Click the **⚙️ Settings** icon (gear icon) next to "Project Overview"
2. Select **Project settings**
3. Scroll down to "Your apps" section
4. If you don't see an Android app, click **"Add app"** and select the **Android** icon
5. Fill in the registration form:
   - **Android package name**: `com.attendance.attendance_app` (must match exactly!)
   - **App nickname**: "Attendance App" (optional)
   - **Debug signing certificate**: Skip for now
6. Click **"Register app"**
7. Click **"Download google-services.json"**

### In Your Project:
1. Copy the downloaded `google-services.json` file
2. Paste it into: `d:/FacialRecognitionForAutomaticAttendance/android/app/`
3. ✅ Android configuration complete!

## Step 3: Download iOS Configuration

### In Firebase Console:
1. Still in **Project settings** → "Your apps" section
2. Click **"Add app"** and select the **iOS** icon
3. Fill in the registration form:
   - **iOS bundle ID**: `com.attendance.attendanceApp` (must match exactly!)
   - **App nickname**: "Attendance App" (optional)
   - **App Store ID**: Skip for now
4. Click **"Register app"**
5. Click **"Download GoogleService-Info.plist"**

### In Your Project:
1. Copy the downloaded `GoogleService-Info.plist` file
2. Paste it into: `d:/FacialRecognitionForAutomaticAttendance/ios/Runner/`
3. ✅ iOS configuration complete!

## Step 4: Configure Web (Without This Step, Web Fails!)

### In Firebase Console:
1. Still in **Project settings** → "Your apps" section
2. Click **"Add app"** and select the **Web** icon (`</>`)
3. Fill in:
   - **App nickname**: "Attendance App Web"
   - ✅ Check "Also set up Firebase Hosting" (optional)
4. Click **"Register app"**
5. You'll see a configuration code that looks like this:

```javascript
const firebaseConfig = {
  apiKey: "AIza...your-api-key",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef123456"
};
```

6. **Copy all the values** from this config

### In Your Project:
1. Open `d:/FacialRecognitionForAutomaticAttendance/web/index.html`
2. Find the `<body>` section (near the end)
3. **Before** `<script src="flutter.js" defer></script>`, add:

```html
<!-- Firebase Configuration -->
<script type="module">
  import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
  
  const firebaseConfig = {
    apiKey: "YOUR-API-KEY",
    authDomain: "YOUR-PROJECT.firebaseapp.com",
    projectId: "YOUR-PROJECT-ID",
    storageBucket: "YOUR-PROJECT.appspot.com",
    messagingSenderId: "YOUR-SENDER-ID",
    appId: "YOUR-APP-ID"
  };
  
  // Initialize Firebase
  const app = initializeApp(firebaseConfig);
  window.firebaseApp = app;
</script>
```

4. **Replace** the placeholder values with your actual Firebase config
5. ✅ Web configuration complete!

## Step 5: Enable Authentication

1. In Firebase Console, click **Authentication** from the left menu
2. Click **"Get started"** if you haven't already
3. Go to **"Sign-in method"** tab
4. Click on **"Email/Password"**
5. Toggle **Enable** to ON
6. Click **"Save"**

## Step 6: Enable Firestore Database

1. In Firebase Console, click **Firestore Database** from the left menu
2. Click **"Create database"**
3. Select **"Start in test mode"** (you can secure it later)
4. Choose a location close to your users
5. Click **"Enable"**

## Step 7: Enable Storage

1. In Firebase Console, click **Storage** from the left menu
2. Click **"Get started"**
3. Use default security rules for now
4. Choose same location as Firestore
5. Click **"Done"**

## Step 8: Update Your Flutter App

### Uncomment Firebase Dependencies:
1. Open `d:/FacialRecognitionForAutomaticAttendance/pubspec.yaml`
2. Find the commented Firebase lines (around line 44-47)
3. Uncomment them:

```yaml
# Firebase for auth and cloud sync
firebase_core: ^2.24.2
firebase_auth: ^4.15.3
firebase_storage: ^11.5.6
cloud_firestore: ^4.13.6
```

4. Save the file
5. Run: `flutter pub get`

### Uncomment Firebase in main.dart:
1. Open `d:/FacialRecognitionForAutomaticAttendance/lib/main.dart`
2. Uncomment line 3: `// import 'package:firebase_core/firebase_core.dart';`
3. Uncomment line 16: `// await Firebase.initializeApp();`

### Restore auth_service.dart:
1. Open `d:/FacialRecognitionForAutomaticAttendance/lib/shared/services/auth_service.dart`
2. Uncomment the full Firebase implementation
3. Delete the temporary mock AuthService

## Step 9: Test Your App!

```bash
cd d:/FacialRecognitionForAutomaticAttendance
flutter pub get
flutter run -d chrome
```

## 🎯 Quick Checklist

- [ ] Downloaded `google-services.json` → placed in `android/app/`
- [ ] Downloaded `GoogleService-Info.plist` → placed in `ios/Runner/`
- [ ] Added Firebase config to `web/index.html`
- [ ] Enabled Email/Password authentication
- [ ] Created Firestore database
- [ ] Enabled Storage
- [ ] Uncommented Firebase dependencies in `pubspec.yaml`
- [ ] Uncommented Firebase in `main.dart`
- [ ] Restored `auth_service.dart`
- [ ] Run `flutter pub get`

## 🚨 Common Issues

**Q: Web app still fails?**
A: Make sure you added the Firebase config to `web/index.html` - this is critical!

**Q: Package name mismatch?**
A: Android package must be `com.attendance.attendance_app`, iOS bundle must be `com.attendance.attendanceApp`

**Q: "Firebase not initialized"?**
A: Make sure you uncommented `await Firebase.initializeApp()` in main.dart

## 📝 Notes

- For now, the app will run **without** Firebase (authentication won't work)
- Once you add config files and uncomment code, authentication will work
- The web config is **required** for web to work - you can't skip it!
