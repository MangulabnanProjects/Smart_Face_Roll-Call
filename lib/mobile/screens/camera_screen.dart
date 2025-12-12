import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

/// Simple clean camera
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  int _currentCameraIndex = 0;
  bool _isFlashOn = false;
  
  // Aspect ratio - default 3:4
  String _aspectRatio = '3:4';
  final List<String> _aspectRatios = ['1:1', '3:4', '9:16', 'Full'];
  
  // Animation state
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      _controller = CameraController(
        _cameras![_currentCameraIndex],
        ResolutionPreset.high, // Default high quality
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null) return;

    try {
      // Trigger flash animation
      if (mounted) {
        setState(() => _isCapturing = true);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _isCapturing = false);
        });
      }

      await Permission.storage.request();
      await Permission.photos.request();
      await Permission.manageExternalStorage.request();

      // Capture at maximum quality
      final image = await _controller!.takePicture();
      
      final currentUser = FirebaseAuth.instance.currentUser;
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'AttendanceApp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Save to user-specific directory (for personal gallery)
      if (currentUser != null) {
        final userImagesPath = Directory('${directory.path}/images/${currentUser.uid}');
        if (!await userImagesPath.exists()) {
          await userImagesPath.create(recursive: true);
        }
        final userSavedPath = '${userImagesPath.path}/$fileName';
        await File(image.path).copy(userSavedPath);
      }
      
      // Also save to shared directory (for recent captures - global)
      final sharedImagesPath = Directory('${directory.path}/images/shared');
      if (!await sharedImagesPath.exists()) {
        await sharedImagesPath.create(recursive: true);
      }
      final sharedSavedPath = '${sharedImagesPath.path}/$fileName';
      await File(image.path).copy(sharedSavedPath);
      
      // Save to phone's DCIM folder with maximum quality
      try {
        final dcimDir = Directory('/storage/emulated/0/DCIM/AttendanceApp');
        if (!await dcimDir.exists()) {
          await dcimDir.create(recursive: true);
        }
        await File(image.path).copy('${dcimDir.path}/$fileName');
      } catch (e) {
        debugPrint('DCIM save failed: $e');
      }

// SnackBar removed per user request
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    try {
      await _controller!.setFlashMode(_isFlashOn ? FlashMode.off : FlashMode.torch);
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;
    
    final newController = CameraController(
      _cameras![_currentCameraIndex],
      ResolutionPreset.max, // Maximum quality
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller?.dispose();
    _controller = newController;

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Flip error: $e');
    }
  }

  double _getAspectRatio() {
    switch (_aspectRatio) {
      case '1:1':
        return 1 / 1;
      case '3:4':
        return 3 / 4;
      case '9:16':
        return 9 / 16;
      default:
        return 0; // Full
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized
          ? Stack(
              children: [
                // Camera preview
                Center(
                  child: _aspectRatio == 'Full'
                      ? SizedBox.expand(
                          child: CameraPreview(_controller!),
                        )
                      : AspectRatio(
                          aspectRatio: _getAspectRatio(),
                          child: CameraPreview(_controller!),
                        ),
                ),

                // Flash animation overlay
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _isCapturing ? 0.8 : 0.0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      color: Colors.white,
                    ),
                  ),
                ),
                
                // Top bar
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close button
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                        
                        // Flash button
                        IconButton(
                          icon: Icon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: _toggleFlash,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Aspect ratio selector - right side
                Positioned(
                  right: 20,
                  top: MediaQuery.of(context).size.height * 0.4,
                  child: Column(
                    children: _aspectRatios.map((ratio) {
                      return GestureDetector(
                        onTap: () => setState(() => _aspectRatio = ratio),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _aspectRatio == ratio 
                                ? Colors.white 
                                : Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ratio,
                            style: TextStyle(
                              color: _aspectRatio == ratio 
                                  ? Colors.black 
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                // Bottom controls
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery
                      IconButton(
                        icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
                        onPressed: () => Navigator.pushNamed(context, '/gallery'),
                      ),
                      
                      // Capture button
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      
                      // Flip camera
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32),
                        onPressed: _flipCamera,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
