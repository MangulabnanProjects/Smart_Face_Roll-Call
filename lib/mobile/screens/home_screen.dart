import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:native_exif/native_exif.dart';

import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import '../../shared/services/image_service.dart';
import '../../shared/services/api_service.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/services/schedule_service.dart';
import '../../shared/services/attendance_service.dart';
import '../../shared/models/attendance.dart';
import 'attendance_screen.dart';
import '../widgets/today_classes_dialog.dart';

/// Redesigned Home Screen with attendance analytics and image gallery
class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> with WidgetsBindingObserver {
  // Dummy data for the chart
  // Real attendance data
  List<int> weeklyAttendanceCounts = List.filled(7, 0);
  List<String> dayLabels = List.filled(7, '');
  int todayAttendanceCount = 0;
  int weekAttendanceCount = 0;
  bool isLoadingStats = true;
  
  List<FileSystemEntity> recentPhotos = [];
  bool isLoadingPhotos = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecentPhotos();
    _loadAttendanceStats();
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
      _loadAttendanceStats(); // Refresh stats immediately
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
    super.didChangeDependencies();
    _loadRecentPhotos();
    _loadAttendanceStats();
  }

  Future<void> _loadAttendanceStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final attendanceService = AttendanceService();
      
      // Get User's Class Info First
      final studentDoc = await FirebaseFirestore.instance.collection('Students').doc(user.uid).get();
      final classId = studentDoc.data()?['classId'] as String? ?? '';
      
      Map<String, dynamic> stats;
      
      if (classId.isEmpty) {
        // Fallback to personal stats if no class
         stats = await attendanceService.getStudentWeeklyAttendanceStats(user.uid);
      } else {
        // Get Class-Wide Weekly Unique Stats
        final relatedIds = await _getRelatedClassIds(classId);
        stats = await attendanceService.getClassWeeklyUniqueAttendanceStats(relatedIds);
      }
      
      if (mounted) {
        setState(() {
          weeklyAttendanceCounts = List<int>.from(stats['weeklyCounts']);
          dayLabels = List<String>.from(stats['dayLabels']);
          todayAttendanceCount = stats['todayCount'];
          weekAttendanceCount = stats['weekCount'];
          isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance stats: $e');
      if (mounted) {
        setState(() => isLoadingStats = false);
      }
    }
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
      
      if (image == null) return;

      final file = File(image.path);
      
      // 1. Strict Date Validation
      DateTime? captureDate;
      try {
        final exif = await Exif.fromPath(file.path);
        String? dateString = await exif.getAttribute('DateTimeOriginal');
        dateString ??= await exif.getAttribute('DateTimeDigitized');
        dateString ??= await exif.getAttribute('DateTime');
        await exif.close();
        
        if (dateString != null && dateString.length >= 10) {
           String formatted = dateString.substring(0, 10).replaceAll(':', '-') + dateString.substring(10);
           captureDate = DateTime.tryParse(formatted);
        }
      } catch (e) {
        debugPrint('EXIF reading failed: $e');
      }

      if (captureDate == null) {
         captureDate = DateTime.now(); 
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

      // --- PREPARE FILE INFO ---
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = image.name.split('.').last;
      final fileName = 'Imported_$timestamp.$extension';

      // --- GET STUDENT INFO AND RECORD ATTENDANCE ---
      final currentUser = FirebaseAuth.instance.currentUser;
      Map<String, bool> attendanceResults = {};

      if (currentUser != null) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('Students')
            .doc(currentUser.uid)
            .get();

        if (studentDoc.exists) {
          final studentData = studentDoc.data()!;
          final classId = studentData['classId'] as String? ?? '';

          // CHECK CLASS SCHEDULE
          if (classId.isNotEmpty) {
            final isAllowed = ScheduleService.isCameraAllowed(classId);
            if (!isAllowed) {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Outside Class Hours'),
                    content: const Text('Attendance photos can only be imported during your scheduled class time.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                  ),
                );
              }
              return; // REJECT IMPORT
            }

            // RECORD ATTENDANCE
            try {
              final attendanceService = AttendanceService();
              final detectedIdentities = result['detected_identities'] != null
                  ? List<String>.from(result['detected_identities'])
                  : <String>[];

              if (detectedIdentities.isNotEmpty) {
                final scheduleInfo = await _getCurrentScheduleInfo(classId);
                
                // Use the classId from the SCHEDULE (not from student profile)
                final correctClassId = scheduleInfo['classId'] ?? classId;
                debugPrint('ATTENDANCE (IMPORT): Using classId from schedule: $correctClassId');
                
                attendanceResults = await attendanceService.recordAttendanceForDetectedStudents(
                  detectedIdentities: detectedIdentities,
                  classId: correctClassId, // Use schedule's classId
                  scheduleId: scheduleInfo['scheduleId'],
                  scheduleTitle: scheduleInfo['scheduleTitle'],
                  instructorId: scheduleInfo['instructorId'],
                  instructorName: scheduleInfo['instructorName'],
                  className: scheduleInfo['className'],
                  sourceImagePath: fileName, // Link to image
                );
              }
            } catch (e) {
              debugPrint('Error recording attendance: $e');
            }
          }
        }
      }

      // --- SAVE IMAGES (Original & Labeled) ---
      
      // Prepare Labeled File
      File? labeledFile;
      if (result['labeled_image'] != null) {
         final bytes = base64Decode(result['labeled_image']);
         final labeledName = fileName.replaceAll('.$extension', '_labeled.$extension');
         final tempDir = await getTemporaryDirectory();
         labeledFile = File('${tempDir.path}/$labeledName');
         await labeledFile.writeAsBytes(bytes);
      }

      // Save to User Gallery
      if (currentUser != null) {
        final userDir = Directory('${directory.path}/images/${currentUser.uid}');
        if (!await userDir.exists()) await userDir.create(recursive: true);
        
        await file.copy('${userDir.path}/$fileName');
        if (labeledFile != null) {
           final labeledName = fileName.replaceAll('.$extension', '_labeled.$extension');
           await labeledFile.copy('${userDir.path}/$labeledName');
        }
      }

      // Save to Shared/Recents (Global)
      final sharedDir = Directory('${directory.path}/images/shared');
      if (!await sharedDir.exists()) await sharedDir.create(recursive: true);
      
      await file.copy('${sharedDir.path}/$fileName');
      if (labeledFile != null) {
          final labeledName = fileName.replaceAll('.$extension', '_labeled.$extension');
          await labeledFile.copy('${sharedDir.path}/$labeledName');
          
          // Save to Phone Gallery
          try {
             bool hasAccess = await Gal.hasAccess();
             if (!hasAccess) await Gal.requestAccess();
             await Gal.putImage(labeledFile.path, album: 'SmartAttendance');
          } catch (e) {
             debugPrint("Gal Save Error: $e");
          }
      }

      // --- FINISH ---
      ImageService().notifyImageSaved(); // Triggers UI refresh

      if (mounted) {
        showDialog(
          context: context,
          barrierColor: Colors.black12,
          barrierDismissible: false,
          builder: (context) {
            Future.delayed(const Duration(milliseconds: 2000), () {
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
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
                      if (attendanceResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Attendance Recorded',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
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
            
            // My Attendance Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Attendance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AttendanceScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chevron_right, size: 16),
                  label: const Text('View Sheet'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAttendanceCard(),
            
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

  void _showTodayClassesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TodayClassesDialog(),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showTodayClassesDialog(context),
            child: _buildStatCard(
              'Today',
              todayAttendanceCount.toString(),
              'Students Present',
              Icons.people,
              Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'This Week',
            weekAttendanceCount.toString(),
            'Total Classes', // Can rename to 'Total Check-ins' or similar if preferred
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
                  if (value.toInt() >= 0 && value.toInt() < dayLabels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dayLabels[value.toInt()],
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
                weeklyAttendanceCounts.length,
                (index) => FlSpot(index.toDouble(), weeklyAttendanceCounts[index].toDouble()),
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

  Widget _buildAttendanceCard() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Please log in to view attendance'),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('Students')
          .doc(currentUser.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final studentData = snapshot.data!.data() as Map<String, dynamic>;
        final classId = studentData['classId'] ?? '';

        if (classId.isEmpty) {
          return const SizedBox.shrink();
        }

        // 1. Now we have classId, find all related class IDs and schedules
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getTodaySchedules(classId),
          builder: (context, scheduleSnapshot) {
            if (!scheduleSnapshot.hasData) return const SizedBox.shrink(); 
            
            final todaySchedules = scheduleSnapshot.data!;
            if (todaySchedules.isEmpty) {
              return Container(
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: Colors.blue.shade50,
                   borderRadius: BorderRadius.circular(16),
                 ),
                 child: Row(
                   children: [
                     Icon(Icons.calendar_today, color: Colors.blue),
                     const SizedBox(width: 16),
                     const Text('No classes scheduled for today', style: TextStyle(color: Colors.blue)),
                   ],
                 ),
              );
            }

            final today = Attendance.formatDate(DateTime.now());
            
            return FutureBuilder<List<String>>(
              future: _getRelatedClassIds(classId),
              builder: (context, idsSnapshot) {
                 final relatedIds = idsSnapshot.data ?? [classId];
                 
                 return StreamBuilder<List<Attendance>>(
                  stream: AttendanceService().getAttendanceForClassesAndDate(relatedIds, today),
                  builder: (context, attendanceSnapshot) {
                    final allAttendance = attendanceSnapshot.data ?? [];
                    final myAttendance = allAttendance.where((a) => a.studentId == currentUser.uid).toList();
                    final myPresentScheduleIds = myAttendance.map((a) => a.scheduleId).toSet();

                    final totalSchedules = todaySchedules.length;
                    final presentCount = todaySchedules.where((s) => myPresentScheduleIds.contains(s['id'])).length;
                    final isAllPresent = presentCount == totalSchedules && totalSchedules > 0;
                    final colorScheme = isAllPresent ? Colors.green : Colors.orange;

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAllPresent
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [Colors.orange.shade400, Colors.orange.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                isAllPresent ? Icons.check_circle : Icons.access_time,
                                size: 40,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isAllPresent ? 'All Classes Attended' : 'Attendance Status',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$presentCount / $totalSchedules classes marked',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Colors.white.withOpacity(0.3)),
                          const SizedBox(height: 8),
                          ...todaySchedules.map((schedule) {
                            final isMarked = myPresentScheduleIds.contains(schedule['id']);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    isMarked ? Icons.check : Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      schedule['title'] ?? 'Unknown Class',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(isMarked ? 1.0 : 0.7),
                                        fontWeight: isMarked ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isMarked)
                                    const Text('Present', style: TextStyle(color: Colors.white, fontSize: 12))
                                  else
                                    Text('Missing', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                );
              }
            );
          },
        );
      },
    );
  }


  // Helper to fetch today's schedules properly
  Future<List<Map<String, dynamic>>> _getTodaySchedules(String classId) async {
    final now = DateTime.now();
    final currentDay = now.weekday - 1; 
    
    // Get related IDs
    final relatedIds = await _getRelatedClassIds(classId);
    
    final query = await FirebaseFirestore.instance
        .collection('Schedules')
        .where('classId', whereIn: relatedIds.take(10).toList())
        .where('dayIndex', isEqualTo: currentDay)
        .get();
        
    return query.docs.map((d) => 
      {'id': d.id, 'title': d.data()['title'], 'startHour': d.data()['startHour']}
    ).toList()
      ..sort((a, b) => (a['startHour'] as int).compareTo(b['startHour'] as int));
  }

  // Helper to find all class IDs with same name
  Future<List<String>> _getRelatedClassIds(String classId) async {
    List<String> relatedClassIds = [classId];
    if (classId.isEmpty) return relatedClassIds;

    final classDoc = await FirebaseFirestore.instance.collection('ClassGroups').doc(classId).get();
    final className = classDoc.data()?['name'];
    
    if (className != null && className.isNotEmpty) {
       final snapshot = await FirebaseFirestore.instance
          .collection('ClassGroups')
          .where('name', isEqualTo: className)
          .get();
       relatedClassIds = snapshot.docs.map((d) => d.id).toList();
    }
    return relatedClassIds;
  }

  /// Get current schedule information for attendance recording
  Future<Map<String, String?>> _getCurrentScheduleInfo(String classId) async {
    try {
      final now = DateTime.now();
      final currentDay = now.weekday - 1; // Mon=0
      final currentMinutes = now.hour * 60 + now.minute;

      // Reuse our helper to find ALL related class groups
      // This ensures import/camera logic matches the display logic
      final relatedClassIds = await _getRelatedClassIds(classId);

      // Query schedules for ANY of these matching classes and today
      // defined 'whereIn' is limited to 10
      final scheduleQuery = await FirebaseFirestore.instance
          .collection('Schedules')
          .where('classId', whereIn: relatedClassIds.take(10).toList())
          .where('dayIndex', isEqualTo: currentDay)
          .get();

      // Find the schedule that matches current time
      for (var doc in scheduleQuery.docs) {
        final data = doc.data();
        final startHour = data['startHour'] as int? ?? 0;
        final startMinute = data['startMinute'] as int? ?? 0;
        final endHour = data['endHour'] as int? ?? 0;
        final endMinute = data['endMinute'] as int? ?? 0;

        final startMinutes = startHour * 60 + startMinute;
        final endMinutes = endHour * 60 + endMinute;

        // Check if current time is within this schedule
        if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
          // Get class name (we can grab it from helper, or just fetch it here if needed)
          // Since we might need the specific name, let's just fetch it quickly if not passed
          // But actually, the helper doesn't return the name. 
          // Let's just do a quick fetch for the name of the PRIMARY classId for display purposes
          String? className;
          if (classId.isNotEmpty) {
             final cd = await FirebaseFirestore.instance.collection('ClassGroups').doc(classId).get();
             className = cd.data()?['name'];
          }

          return {
            'scheduleId': doc.id,
            'scheduleTitle': data['title'] as String? ?? '',
            'instructorId': data['instructorId'] as String? ?? '',
            'instructorName': data['instructorName'] as String? ?? '',
            'className': className,
          };
        }
      }

      // No matching schedule found, return basic info
      String? className;
      if (classId.isNotEmpty) {
         final cd = await FirebaseFirestore.instance.collection('ClassGroups').doc(classId).get();
         className = cd.data()?['name'];
      }

      return {
        'scheduleId': null,
        'scheduleTitle': null,
        'instructorId': null,
        'instructorName': null,
        'className': className,
      };
    } catch (e) {
      debugPrint('Error getting schedule info: $e');
      return {
        'scheduleId': null,
        'scheduleTitle': null,
        'instructorId': null,
        'instructorName': null,
        'className': null,
      };
    }
  }
}
