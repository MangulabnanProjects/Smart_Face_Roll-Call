# Running Flutter App on Your Phone Wirelessly

## 🎯 Two Options to Test on Your Phone

### Option 1: Wireless Debugging (Recommended - No USB!)

#### Requirements:
- Android phone (Android 11+)
- Phone and computer on **same WiFi network**
- Developer mode enabled on phone

#### Steps:

**1. Enable Developer Options on Your Phone:**
1. Go to **Settings** → **About Phone**
2. Tap **Build Number** 7 times
3. You'll see "You are now a developer!"

**2. Enable Wireless Debugging:**
1. Go to **Settings** → **Developer Options**
2. Find **Wireless Debugging** and turn it ON
3. Tap on **Wireless Debugging**
4. Tap **Pair device with pairing code**
5. You'll see:
   - WiFi pairing code (6 digits)
   - IP address and port (e.g., `192.168.1.100:12345`)

**3. On Your Computer:**

Open PowerShell and run:
```bash
# Navigate to Android platform tools
cd C:\Users\Alpha\AppData\Local\Android\Sdk\platform-tools

# Pair your device (use the IP and port from your phone)
.\adb pair 192.168.1.100:12345
# Enter the 6-digit pairing code when prompted

# Connect to device
.\adb connect 192.168.1.100:12345
```

**4. Verify Connection:**
```bash
cd d:/FacialRecognitionForAutomaticAttendance
flutter devices
```

You should see your phone listed!

**5. Run the App:**
```bash
flutter run
```

Flutter will ask which device to use - select your phone!

---

### Option 2: Build APK and Install Manually

If wireless debugging doesn't work, build an APK file and transfer it:

#### Steps:

**1. Build the APK:**
```bash
cd d:/FacialRecognitionForAutomaticAttendance
flutter build apk --release
```

This creates: `build/app/outputs/flutter-apk/app-release.apk`

**2. Transfer to Your Phone:**
- **Via Google Drive**: Upload APK, download on phone
- **Via Email**: Email to yourself, open on phone
- **Via Bluetooth**: Send from computer to phone
- **Via Cloud Storage**: Dropbox, OneDrive, etc.

**3. Install on Phone:**
1. Open the APK file on your phone
2. Allow "Install from unknown sources" if prompted
3. Tap **Install**
4. Open the Attendance App!

---

## ⚠️ Before You Run: Add Firebase Config for Android

Your phone won't work yet without the Android Firebase config file!

**Quick Setup:**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select **audioanalysisdb** project
3. Click **⚙️ Settings** → **Project Settings**
4. Scroll to "Your apps"
5. Click **Android** icon to add Android app
6. **Android package name**: `com.attendance.attendance_app` (EXACT!)
7. Click **Register app**
8. Download `google-services.json`
9. Place it in: `d:/FacialRecognitionForAutomaticAttendance/android/app/`

Then you can run on phone!

---

## 🚀 Quick Start Commands

**Wireless Debug Setup:**
```bash
# Step 1: Pair (one time only)
cd C:\Users\Alpha\AppData\Local\Android\Sdk\platform-tools
.\adb pair <YOUR_PHONE_IP>:<PORT>

# Step 2: Connect
.\adb connect <YOUR_PHONE_IP>:<PORT>

# Step 3: Run app
cd d:/FacialRecognitionForAutomaticAttendance
flutter run
```

**Build APK:**
```bash
cd d:/FacialRecognitionForAutomaticAttendance
flutter build apk --release
```
APK location: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🔧 Troubleshooting

**"No devices found"**
- Make sure phone and computer are on same WiFi
- Try reconnecting: `adb connect <IP>:<PORT>`

**"Wireless debugging not available"**
- Requires Android 11+ (check your Android version)
- Make sure Developer Options are enabled

**"Installation blocked"**
- On phone: Settings → Security → Enable "Install unknown apps"

**"Firebase error on phone"**
- Did you add `google-services.json` to `android/app/`?
- Package name must be exactly: `com.attendance.attendance_app`

---

## 💡 Tips

✅ **Phone stays connected** - Once paired, just use `adb connect` in future  
✅ **Hot reload works** wirelessly - Make changes, save, see on phone instantly!  
✅ **APK method** - Works for any Android version, no setup needed  
✅ **Test web first** - Already working on Chrome, mobile is same app!

---

## What You'll See on Phone

📱 Login screen (same as web)  
📱 Home screen with Camera, Gallery buttons  
📱 Camera screen (placeholder - ready to implement)  
📱 Gallery screen (placeholder)  
📱 Working authentication (after Firebase setup)
