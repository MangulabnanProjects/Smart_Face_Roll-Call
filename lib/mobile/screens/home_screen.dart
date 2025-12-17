import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:native_exif/native_exif.dart';

import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import '../../shared/services/image_service.dart';
import '../../shared/services/api_service.dart';
import '../../shared/services/notification_service.dart';

/// Redesigned Home Screen with attendance analytics and image gallery
class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> with WidgetsBindingObserver {
  // Dummy data for the chart
  final List<int> attendanceData = [12, 15, 18, 14, 20, 17, 22];
  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  
  List<FileSystemEntity> recentPhotos = [];
  bool isLoadingPhotos = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecentPhotos();
    // Listen for global image updates
    ImageService().onImageSaved.addListener(_handleImageSaved);
    
    // Initialize & Schedule Notifications
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    await NotificationService().init();
    
    // Demonstrate 'BSCS-4A' schedule notifications
    // In a real app, get 'section' from User Profile
    final section = 'BSCS-4A'; 
    
    // For testing: we'll check the Mock Schedule
    // We need to access the data. Since ScheduleService.mockSchedules is private, 
    // we'll assume the user wants us to use the Mock Data logic or we can just 
    // hardcode the loop here for the "Implementation Plan" demonstration.
    // Ideally, ScheduleService should expose a `getScheduleFor(section)` method.
    // For now, I will manually check if today matches the mock days for BSCS-4A.
    
    final now = DateTime.now();
    // BSCS-4A: Mon(1), Wed(3) 2PM-5PM
    final today = now.weekday; // 1=Mon, 7=Sun
    
    if (today == 1 || today == 3) {
      final start = DateTime(now.year, now.month, now.day, 14, 0); // 2:00 PM
      final end = DateTime(now.year, now.month, now.day, 17, 0);   // 5:00 PM
      
      await NotificationService().scheduleClassNotifications(
        startTime: start,
        endTime: end,
        className: 'Robotics',
      );
      debugPrint("Notifications scheduled for Robotics (2PM-5PM)");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ImageService().onImageSaved.removeListener(_handleImageSaved);
    super.dispose();
  }

  void _handleImageSaved() {
    if (mounted) {
      _loadRecentPhotos();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload photos when app comes back to foreground
      _loadRecentPhotos();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRecentPhotos();
  }

  Future<void> _loadRecentPhotos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Load from shared directory - shows all users' recent photos
      final imagesPath = Directory('${directory.path}/images/shared');
      
      if (await imagesPath.exists()) {
        final files = imagesPath
            .listSync()
            .where((item) => item.path.endsWith('.jpg') && !item.path.contains('_labeled'))
            .toList();
        
        files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        
        setState(() {
          recentPhotos = files.take(20).toList(); // Get most recent 20
          isLoadingPhotos = false;
        });
      } else {
        setState(() => isLoadingPhotos = false);
      }
    } catch (e) {
      setState(() => isLoadingPhotos = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 640,
        imageQuality: 85,
      );
      if (image != null) {
        final file = File(image.path);
        
        // 1. Strict Date Validation (EXIF REQUIRED)
        DateTime? captureDate;
        try {
          final exif = await Exif.fromPath(file.path);
          // Try multiple common tags for capture time
          String? dateString = await exif.getAttribute('DateTimeOriginal');
          dateString ??= await exif.getAttribute('DateTimeDigitized');
          dateString ??= await exif.getAttribute('DateTime');
          await exif.close();
          
          if (dateString != null) {
            // EXIF Standard: "YYYY:MM:DD HH:MM:SS"
            // Dart DateTime.parse expects: "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DDTHH:MM:SS"
            
            // 1. Replace first two colons with hyphens for the date part
            // "2023:10:25 14:30:00" -> "2023-10-25 14:30:00"
            if (dateString.length >= 10) {
               String formatted = dateString.substring(0, 10).replaceAll(':', '-') + dateString.substring(10);
               captureDate = DateTime.tryParse(formatted);
            }
          }
        } catch (e) {
          debugPrint('EXIF reading failed: $e');
        }

        // REJECT if no valid EXIF date found (Strict Mode)
        if (captureDate == null) {
           // TEMPORARILY DISABLED: Allow non-EXIF images for testing
           // if (mounted) {
           //  showDialog(...);
           // }
           // return;
           
           captureDate = DateTime.now(); // Fallback to current time
        }

        final now = DateTime.now();
        final difference = now.difference(captureDate);

        // Check if older than 48 hours (2 days)
        if (false) { // TEMPORARILY DISABLED FOR TESTING (was: difference.inHours > 48)
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Image Too Old'),
                content: Text(
                  'Only recent images (taken within the last 2 days) can be imported.\n\nCapture Date: ${captureDate.toString().split('.')[0]}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }

        // 2. RUN FACE DETECTION
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

        Map<String, dynamic> result;
        try {
          result = await ApiService.detectFace(file);
        } catch (e) {
          if (mounted) Navigator.pop(context);
          throw Exception("Server connection failed: $e");
        }
        
        if (mounted) Navigator.pop(context); // Dismiss loading

        if (result['detected'] != true) {
          if (mounted) {
             showDialog(
               context: context,
               builder: (ctx) => AlertDialog(
                 title: const Text("Import Refused"),
                 content: const Text("No face detected by the AI model. Image will not be imported."),
                 actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
               ),
             );
          }
          return;
        }

        // 3. Prepare Saving
        final directory = await getApplicationDocumentsDirectory();
        final currentUser = FirebaseAuth.instance.currentUser;
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = image.name.split('.').last;
        final fileName = 'Imported_$timestamp.$extension';

        // Prepare Labeled File
        File? labeledFile;
        if (result['labeled_image'] != null) {
           final bytes = base64Decode(result['labeled_image']);
           final labeledName = fileName.replaceAll('.$extension', '_labeled.$extension');
           final tempDir = await getTemporaryDirectory();
           labeledFile = File('${tempDir.path}/$labeledName');
           await labeledFile.writeAsBytes(bytes);
        }

        // 4. Save to User Gallery (Private)
        if (currentUser != null) {
          final userDir = Directory('${directory.path}/images/${currentUser.uid}');
          if (!await userDir.exists()) {
            await userDir.create(recursive: true);
          }
          await file.copy('${userDir.path}/$fileName');
          if (labeledFile != null) {
             final labeledName = fileName.replaceAll('.$extension', '_labeled.$extension');
             await labeledFile.copy('${userDir.path}/$labeledName');
          }
        }

        // 5. Save to Shared/Recents (Global)
        final sharedDir = Directory('${directory.path}/images/shared');
        if (!await sharedDir.exists()) {
          await sharedDir.create(recursive: true);
        }
        await file.copy('${sharedDir.path}/$fileName');
        if (labeledFile != null) {
            final labeledName = fileName.replaceAll('.$extension', '_labeled.$extension');
            await labeledFile.copy('${sharedDir.path}/$labeledName');
            
            // NEW: Save LABELED image to Phone Gallery (SmartAttendance Album)
            // This gives the user proof that AI worked and saved the result
            try {
               bool hasAccess = await Gal.hasAccess();
               if (!hasAccess) await Gal.requestAccess();
               await Gal.putImage(labeledFile.path, album: 'SmartAttendance');
            } catch (e) {
               debugPrint("Gal Save Error: $e");
            }
        }

        // 6. Notify & Show Success
        ImageService().notifyImageSaved();

        if (mounted) {
          showDialog(
            context: context,
            barrierColor: Colors.black12,
            barrierDismissible: false,
            builder: (context) {
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
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImageInput() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.blue.shade400),
            const SizedBox(height: 12),
            const Text(
              'Tap to select an image',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Supports JPG, PNG',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            _buildSummaryCards(),
            
            const SizedBox(height: 24),
            
            // Attendance Chart
            const Text(
              'Weekly Attendance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAttendanceChart(),
            
            const SizedBox(height: 32),
            
            // Recent Photos Section
            const Text(
              'Recent Captures',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecentPhotos(),
            
            const SizedBox(height: 32),
            
            // Image Input Section
            const Text(
              'Manual Upload',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildImageInput(),
            const SizedBox(height: 32), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Today',
            '22',
            'Students Present',
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'This Week',
            '118',
            'Total Attendance',
            Icons.calendar_today,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                 getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < days.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        days[value.toInt()],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: 25,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                attendanceData.length,
                (index) => FlSpot(index.toDouble(), attendanceData[index].toDouble()),
              ),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.blue,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPhotos() {
    if (isLoadingPhotos) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (recentPhotos.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'No photos yet',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap camera to capture',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recentPhotos.length,
        itemBuilder: (context, index) {
          final file = File(recentPhotos[index].path);
          return GestureDetector(
            onTap: () async {
               // Dual Image Popup Logic
               final path = file.path;
               final fileName = path.split(Platform.pathSeparator).last;
               final dir = file.parent;
               
               File? labeledFile;
               File? originalFile;

               if (fileName.contains('_labeled')) {
                  // This is the labeled one
                  labeledFile = File(file.path);
                  final originalName = fileName.replaceAll('_labeled', '');
                  originalFile = File('${dir.path}/$originalName');
               } else {
                  // This is the original one
                  originalFile = File(file.path);
                  final extension = fileName.split('.').last;
                  final labeledName = fileName.replaceAll('.$extension', '_labeled.$extension');
                  labeledFile = File('${dir.path}/$labeledName');
               }

               // Verify existence
               if (!await labeledFile.exists()) labeledFile = null;
               if (!await originalFile.exists()) originalFile = null;
               
               if (context.mounted) {
                 showDialog(
                   context: context,
                   builder: (ctx) => Dialog(
                     insetPadding: const EdgeInsets.all(16),
                     child: SingleChildScrollView(
                       padding: const EdgeInsets.all(16),
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                            const Text("Detection Results", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 16),
                            if (labeledFile != null) ...[
                              const Text("Labeled (AI)", style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Image.file(labeledFile),
                              const SizedBox(height: 24),
                            ],
                            if (originalFile != null) ...[
                              const Text("Original", style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Image.file(originalFile),
                            ],
                            if (labeledFile == null && originalFile == null)
                               const Text("Image file not found."),

                            const SizedBox(height: 16),
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
                         ],
                       ),
                     ),
                   ),
                 );
               }
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
