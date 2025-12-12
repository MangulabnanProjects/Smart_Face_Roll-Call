# Attendance App - Flutter Project

A cross-platform Flutter application for facial recognition-based attendance tracking, with a mobile app for image capture and a web dashboard for data analytics.

## 🎯 Project Overview

This is a **startup/initial version** of the attendance tracking system with:

- **Mobile App (Primary)**: Camera integration, image capture, gallery, and cloud sync
- **Web Dashboard**: Admin interface with analytics visualization and data management
- **Admin Authentication**: Login/signup system for both platforms
- **AI Model Ready**: Placeholder architecture for facial recognition integration

## 📋 Current Features

### Mobile Application
- ✅ Admin login/signup
- ✅ Home screen with navigation
- ✅ Camera screen (placeholder - ready for implementation)
- ✅ Gallery screen (placeholder - ready for implementation)
- ✅ AI model service interface (ready for model integration)

### Web Dashboard
- ✅ Admin login/signup
- ✅ Top navigation bar with user menu
- ✅ Left sidebar navigation
- ✅ Dashboard with stat cards
- ✅ Dummy action buttons
- ✅ Responsive layout

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.10.0 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Chrome browser (for web testing)

### Installation

1. **Clone or navigate to the project directory:**
   ```bash
   cd d:/FacialRecognitionForAutomaticAttendance
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**

   **For Web:**
   ```bash
   flutter run -d chrome
   ```

   **For Android:**
   ```bash
   flutter run -d <your-device-id>
   ```

   **For iOS:**
   ```bash
   flutter run -d <your-device-id>
   ```

### Firebase Setup (Required for Authentication)

To enable authentication and cloud features:

1. **Create a Firebase project** at [https://console.firebase.google.com](https://console.firebase.google.com)

2. **Add your apps:**
   - Add Android app (download `google-services.json` → place in `android/app/`)
   - Add iOS app (download `GoogleService-Info.plist` → place in `ios/Runner/`)
   - Add Web app (copy config → update `web/index.html`)

3. **Enable Authentication:**
   - In Firebase Console → Authentication → Sign-in method
   - Enable "Email/Password"

4. **Enable Firestore and Storage:**
   - Firestore Database → Create database
   - Storage → Get started

5. **Uncomment Firebase initialization in `lib/main.dart`:**
   ```dart
   await Firebase.initializeApp();
   ```

## 🤖 AI Model Integration

The app includes a **placeholder service** for facial recognition. To integrate your AI model:

1. **Add your model file** to `assets/` directory
2. **Update `pubspec.yaml` to include the model:**
   ```yaml
   flutter:
     assets:
       - assets/your_model.tflite
   ```

3. **Edit `lib/shared/services/face_recognition_service.dart`:**
   - Replace mock initialization with actual model loading
   - Implement `recognizeFace()` method with your model inference
   - Update `RecognitionResult` model if needed

**Recommended packages for AI:**
- `tflite_flutter` for TensorFlow Lite models
- `onnxruntime` for ONNX models
- Custom model integration as needed

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── mobile/
│   ├── screens/
│   │   ├── home_screen.dart          # Mobile home
│   │   ├── camera_screen.dart        # Camera (placeholder)
│   │   └── gallery_screen.dart       # Gallery (placeholder)
│   └── widgets/
├── web/
│   ├── screens/
│   │   └── dashboard_screen.dart     # Web dashboard
│   └── widgets/
│       ├── web_navbar.dart           # Top navbar
│       └── web_sidebar.dart          # Side navigation
└── shared/
    ├── screens/
    │   └── login_screen.dart         # Auth screen
    ├── services/
    │   ├── auth_service.dart         # Firebase auth
    │   └── face_recognition_service.dart  # AI model placeholder
    └── models/
        └── recognition_result.dart   # Recognition data model
```

## 🔧 Next Steps (TODOs)

### High Priority
- [ ] Set up Firebase project and configure apps
- [ ] Implement actual camera functionality in `camera_screen.dart`
- [ ] Add image storage (local + Firebase Storage sync)
- [ ] Integrate facial recognition AI model
- [ ] Add camera and storage permissions

### Medium Priority
- [ ] Implement gallery with real images
- [ ] Add image metadata and recognition results display
- [ ] Create data visualization charts for web dashboard
- [ ] Implement user management
- [ ] Add settings screens

### Low Priority
- [ ] Export functionality
- [ ] Offline support
- [ ] Push notifications
- [ ] Advanced analytics

## 📦 Dependencies

**Core:**
- `flutter` - Framework
- `firebase_core` - Firebase SDK
- `firebase_auth` - Authentication
- `firebase_storage` - Cloud storage
- `cloud_firestore` - Database

**Camera & Images:**
- `camera` - Camera integration
- `image_picker` - Image selection
- `path_provider` - File paths

**Utilities:**
- `shared_preferences` - Local storage
- `intl` - Date formatting

## 🧪 Testing

**Analyze code:**
```bash
flutter analyze
```

**Run tests:**
```bash
flutter test
```

**Build for production:**
```bash
# Android
flutter build apk

# iOS
flutter build ios

# Web
flutter build web
```

## 📝 Notes

- Firebase is currently **disabled** in `main.dart` - uncomment after setup
- Camera and gallery screens are **placeholders** - ready for implementation
- AI model service returns **mock data** - integrate your actual model
- Admin role management is **partially implemented** - needs Firebase setup

## 🤝 Contributing

This is a startup version. Key areas for contribution:
1. Camera implementation
2. AI model integration
3. Data visualization
4. Testing coverage

## 📄 License

[Add your license here]
