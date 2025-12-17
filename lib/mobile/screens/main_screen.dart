import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../../shared/services/image_service.dart';
import '../../shared/services/api_service.dart';
import 'gallery_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

/// Main mobile app with bottom navigation
class MobileMainScreen extends StatefulWidget {
  const MobileMainScreen({super.key});

  @override
  State<MobileMainScreen> createState() => _MobileMainScreenState();
}

class _MobileMainScreenState extends State<MobileMainScreen> {
  int _currentIndex = 0;
  bool? _hasConsentCache; // Local cache to speed up launches

  final List<Widget> _screens = [
    const MobileHomeScreen(),
    const GalleryScreen(),
    const SizedBox(), // Placeholder for Camera tab
    const ScheduleScreen(), // Instructor schedule viewer
    const ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == 2) {
      _checkConsentAndOpenCamera();
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Future<void> _checkConsentAndOpenCamera() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first')),
        );
      }
      return;
    }

    // 1. Check local cache first (Fastest)
    if (_hasConsentCache == true) {
      _openNativeCamera();
      return;
    }

    try {
      // 2. Fetch from Firestore if not cached
      final doc = await FirebaseFirestore.instance
          .collection('Students')
          .doc(user.uid)
          .get();

      final data = doc.data();
      final hasConsent = data?['hasCameraConsent'] == true;

      // Update cache
      setState(() => _hasConsentCache = hasConsent);

      if (hasConsent) {
        _openNativeCamera();
      } else {
        if (mounted) _showConsentDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking consent: $e')),
        );
      }
    }
  }

  void _showConsentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Camera Access Required'),
        content: const Text(
          'I will use the camera for the attendance image capture. Do you agree?',
        ),
        actions: [
          // Gallery Option
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('Gallery'),
          ),
          // Cancel
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // Agree
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _grantConsent();
            },
            child: const Text('Agree'),
          ),
        ],
      ),
    );
  }

  Future<void> _grantConsent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Optimistically update cache immediately
      setState(() => _hasConsentCache = true);

      await FirebaseFirestore.instance
          .collection('Students')
          .doc(user.uid)
          .set({'hasCameraConsent': true}, SetOptions(merge: true));
      
      _openNativeCamera();
    } catch (e) {
      setState(() => _hasConsentCache = false); // Revert on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving consent: $e')),
        );
      }
    }
  }

  Future<void> _openNativeCamera() async {
    // Request permissions to ensure best experience (native gallery thumb)
    await [
      Permission.camera,
      Permission.storage,
      // Permission.photos, // Uncomment if targeting newer Android/iOS 
    ].request();

    _pickImage(ImageSource.camera);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 640, // 640 is standard YOLO input size, much faster upload
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        // Show loading spinner while "processing"
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dContext) => const Center(child: CircularProgressIndicator()),
        );

        // Fast processing
        await Future.delayed(const Duration(milliseconds: 50));

        if (mounted) {
          Navigator.pop(context); // Dismiss spinner
          _showSendDialog(File(photo.path));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.settings.name != 'loading'); // Safety message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _saveImageToLocations(File sourceFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'Attendance_$timestamp.jpg';

      // Show processing 
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dContext) => const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                   CircularProgressIndicator(),
                   SizedBox(width: 20),
                   Text("Analyzing Face..."),
                ],
              ),
            ),
          ),
        );
      }

      // 0. RUN FACE DETECTION
      Map<String, dynamic> result;
      try {
        result = await ApiService.detectFace(sourceFile);
      } catch (e) {
        if (mounted) Navigator.pop(context); // Dismiss processing ID
        throw Exception("Server connection failed: $e");
      }

      if (mounted) Navigator.pop(context); // Dismiss processing ID

      final bool isDetected = result['detected'] == true;
      
      if (!isDetected) {
         if (mounted) {
           showDialog(
             context: context,
             builder: (ctx) => AlertDialog(
               title: const Text("Refused"),
               content: const Text("No face detected by the AI model. Image will not be saved."),
               actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
             ),
           );
         }
         return; // STOP SAVING
      }

      // --- IF DETECTED, PROCEED TO SAVE ---

      // 1. Phone Gallery (Public) - ORIGINAL ONLY
      // Use Gal to ensure it shows up in Recents/Gallery app immediately
      try {
        // Request access first (Gal handles this but good to be explicit/safe)
        bool hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
           await Gal.requestAccess();
        }
        await Gal.putImage(sourceFile.path, album: 'SmartAttendance');
      } catch (e) {
        debugPrint('Failed to save to Gallery via Gal: $e');
        // Fallback or just log
      }

      // PREPARE LABELED IMAGE
      File? labeledFile;
      if (result['labeled_image'] != null) {
         final bytes = base64Decode(result['labeled_image']);
         final labeledName = fileName.replaceAll('.jpg', '_labeled.jpg');
         final tempDir =  await getTemporaryDirectory(); // Use temp to write first
         labeledFile = File('${tempDir.path}/$labeledName');
         await labeledFile.writeAsBytes(bytes);
      }

      // 2. User Gallery (Private) - BOTH
      if (user != null) {
        final userDir = Directory('${directory.path}/images/${user.uid}');
        if (!await userDir.exists()) {
          await userDir.create(recursive: true);
        }
        await sourceFile.copy('${userDir.path}/$fileName');
        if (labeledFile != null) {
           final labeledName = fileName.replaceAll('.jpg', '_labeled.jpg');
           await labeledFile.copy('${userDir.path}/$labeledName');
        }
      }

      // 3. Shared/Recents (Global) - BOTH
      final sharedDir = Directory('${directory.path}/images/shared');
      if (!await sharedDir.exists()) {
        await sharedDir.create(recursive: true);
      }
      await sourceFile.copy('${sharedDir.path}/$fileName');
      if (labeledFile != null) {
          final labeledName = fileName.replaceAll('.jpg', '_labeled.jpg');
          await labeledFile.copy('${sharedDir.path}/$labeledName');
      }

      // 4. Notify Global Listeners (Refreshes Home & Gallery)
      ImageService().notifyImageSaved();

      if (mounted) {
        // Show custom centered popup (Toast replacement)
        showDialog(
          context: context,
          barrierColor: Colors.black12, // Subtle dim
          barrierDismissible: false,
          builder: (context) {
            // Auto close after 1.5 seconds
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (context.mounted) Navigator.of(context).pop();
            });

            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.face, color: Colors.blueAccent),
                      SizedBox(width: 12),
                      Text(
                        'Face Verified & Saved',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  void _showSendDialog(File imageFile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Send this to the attendance app?'),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                imageFile,
                height: 200,
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // DO NOT SAVE - File is left in cache to be cleaned by OS
            },
            child: const Text('Retake'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _saveImageToLocations(imageFile); // Save ONLY on Send
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTabTapped(2),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.camera_alt, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNavBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0),
            _buildNavItem(Icons.photo_library_outlined, Icons.photo_library, 'Gallery', 1),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Schedule', 3),
            _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData outlinedIcon, IconData filledIcon, String label, int index) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? filledIcon : outlinedIcon,
            color: isSelected ? Colors.blue : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.blue : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
