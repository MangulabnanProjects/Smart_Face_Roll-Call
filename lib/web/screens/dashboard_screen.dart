import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/web_navbar.dart';
import '../widgets/web_sidebar.dart';

import 'manage_screen.dart'; // Import the new screen
import 'users_screen.dart';
import '../../shared/models/class_group.dart';
import '../../shared/models/student.dart'; // Import Student model
import '../../shared/models/class_session.dart'; // Import ClassSession model
import '../../shared/models/attendance.dart'; // Import Attendance model
import '../../shared/services/attendance_service.dart';
import '../../shared/services/student_service.dart'; // Import StudentService
import '../../shared/services/schedule_service.dart'; // Import ScheduleService

/// Web dashboard with attendance analytics and charts
class WebDashboardScreen extends StatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  String _currentPage = 'dashboard'; // Track current page
  String? _selectedClassId; // Selected class from dropdown

  // Real Attendance Data State
  List<int> weeklyAttendanceCounts = List.filled(7, 0);
  List<String> dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  int todayAttendanceCount = 0;
  int weekAttendanceCount = 0;
  bool isLoading = true;
  
  // Attendance Sheet State
  DateTime _selectedDate = DateTime.now();
  List<Student> _classStudents = [];
  List<Attendance> _dailyAttendance = [];
  bool _isSheetLoading = false;
  
  // Schedule/Subject Filter State
  List<ClassSession> _dailySchedules = [];
  String? _selectedScheduleId;
  
  List<ClassGroup> _instructorClasses = [];
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Fetch Instructor's Classes
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ClassGroups')
          .where('instructorId', isEqualTo: user.uid)
          .get();
          
      final classes = snapshot.docs
          .map((doc) => ClassGroup.fromMap(doc.data(), doc.id))
          .toList();
          
      if (mounted) {
        setState(() {
          _instructorClasses = classes;
        });
        // 2. Load Stats for All Classes (Default)
        debugPrint('DASHBOARD: Loaded ${_instructorClasses.length} classes for user ${user.uid}');
        for(var c in _instructorClasses) debugPrint('CLASS: ${c.name} (${c.id})');
        _loadStats();
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Load data for the Attendance Sheet (Students + Attendance)
  Future<void> _loadDailySheetData() async {
     if (!mounted) return;
     setState(() => _isSheetLoading = true);

     final classId = _selectedClassId;
     // If no class selected, we can't really show a roster easily unless we aggregator ALL, which is messy.
     // For now, if "All Classes" is selected, we might default to the first one or show empty.
     // Let's look at the first available class if 'all' is selected to be safe.
     final targetClassId = classId ?? (_instructorClasses.isNotEmpty ? _instructorClasses.first.id : '');

     if (targetClassId.isEmpty) {
       setState(() => _isSheetLoading = false);
       return;
     }

     try {
       final studentService = StudentService();
       final attendanceService = AttendanceService();
       final scheduleService = ScheduleService();

       // 1. Get Roster (Stream converted to Future for this snapshot)
       final studentsStream = studentService.getStudentsByClass(targetClassId);
       final students = await studentsStream.first;
       
       // 2. Get Daily Attendance
       final attendance = await attendanceService.getAttendanceForClassDate(targetClassId, _selectedDate);
       
       // 3. Get Daily Schedules
       final schedules = await scheduleService.getSchedulesForClassDate(targetClassId, _selectedDate);

       if (mounted) {
         setState(() {
           _classStudents = students;
           _dailyAttendance = attendance;
           _dailySchedules = schedules;
           _isSheetLoading = false;
           // Reset filter if not relevant anymore, though we might want to keep it if valid
           _selectedScheduleId = null; 
         });
       }
     } catch (e) {
       debugPrint('Error loading sheet data: $e');
       if (mounted) setState(() => _isSheetLoading = false);
     }
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final attendanceService = AttendanceService();
      
      List<String> targetClassIds = [];

      if (_selectedClassId != null) {
        // Filter by specific class
        targetClassIds = [_selectedClassId!];
      } else {
        // "All Classes": Aggregated stats for all instructor classes
        targetClassIds = _instructorClasses.map((c) => c.id).toList();
      }

      if (targetClassIds.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      // Fetch aggregated stats (works for 1 or many classes)
      debugPrint('DASHBOARD: Fetching stats for class IDs: $targetClassIds');
      final stats = await attendanceService.getClassWeeklyUniqueAttendanceStats(targetClassIds);

      if (mounted) {
        setState(() {
          weeklyAttendanceCounts = List<int>.from(stats['weeklyCounts']);
           // Use dynamic labels if returned, else default
          if (stats['dayLabels'] != null) {
             dayLabels = List<String>.from(stats['dayLabels']);
          }
          todayAttendanceCount = stats['todayCount'];
          weekAttendanceCount = stats['weekCount'];
          isLoading = false;
        });
        
        // Load sheet data after main stats
        _loadDailySheetData();
      }
    } catch (e) {
      debugPrint('Error loading web stats: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

    // Migration tool removed


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          WebSidebar(
            selectedPage: _currentPage,
            onPageSelected: (page) => setState(() => _currentPage = page),
          ),
          Expanded(
            child: Column(
              children: [
                const WebNavbar(),
                Expanded(
                  child: _currentPage == 'manage' 
                    ? const WebManageScreen()
                    : _currentPage == 'users'
                      ? const UsersScreen()
                      : _buildDashboardContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Dashboard',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                     Text(
                      _selectedClassId == null 
                          ? 'Overview of all your classes' 
                          : 'Analytics for ${_instructorClasses.firstWhere((c) => c.id == _selectedClassId, orElse: () => ClassGroup(id: '', name: 'Class', instructorId: '')).name}',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _buildClassDropdown(),
            ],
          ),
          
          const SizedBox(height: 32),
          
          if (isLoading)
             const Center(child: CircularProgressIndicator())
          else ...[
            _buildStatsRow(),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildAttendanceChart(),
                      const SizedBox(height: 24),
                      // Optional: Student list or preview could go here
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(child: _buildQuickStats()),
              ],
            ),
            const SizedBox(height: 32),
             _buildAttendanceSheet(),
            const SizedBox(height: 32),
            _buildRecentActivity(),
          ]
        ],
      ),
    );
  }

  Widget _buildAttendanceSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Date Picker & Subject Filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Attendance Sheet',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Full roster status for selected date',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              
              // 1. Subject Filter Dropdown (Collapsing Folder Logic)
              if (_dailySchedules.isNotEmpty) ...[
                 Container(
                   margin: const EdgeInsets.only(right: 12),
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                   decoration: BoxDecoration(
                     border: Border.all(color: Colors.grey.shade300),
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: DropdownButton<String?>(
                     value: _selectedScheduleId,
                     hint: const Text('All Day'),
                     underline: const SizedBox(),
                     items: [
                       const DropdownMenuItem<String?>(
                         value: null,
                         child: Text('All Day', style: TextStyle(fontWeight: FontWeight.bold)),
                       ),
                       ..._dailySchedules.map((schedule) {
                         return DropdownMenuItem<String?>(
                           value: schedule.id,
                           child: Text('${schedule.title} (${schedule.startTime.hour}:${schedule.startTime.minute.toString().padLeft(2,'0')})'),
                         );
                       }).toList(),
                     ],
                     onChanged: (val) {
                       setState(() => _selectedScheduleId = val);
                     },
                   ),
                 ),
              ],
              
              // Date Picker
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(Attendance.formatDate(_selectedDate)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _loadDailySheetData();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_isSheetLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_classStudents.isEmpty)
             Center(
               child: Padding(
                 padding: const EdgeInsets.all(32), 
                 child: Text('No students found or no class selected.', style: TextStyle(color: Colors.grey.shade500))
               )
             )
          else
            SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(label: Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Time In', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _classStudents.map((student) {
                   // Check if present logic
                   // Default: Present if ANY record found for student today
                   // If Filtered: Present if record matches filter scheduleId
                   
                   Attendance? record;
                   bool isPresent = false;
                   
                   try {
                     if (_selectedScheduleId == null) {
                       // "All Day" - Must attend ALL schedules
                       if (_dailySchedules.isNotEmpty) {
                         final studentRecords = _dailyAttendance.where((a) => a.studentId == student.id).toList();
                         final attendedScheduleIds = studentRecords.map((a) => a.scheduleId).where((id) => id != null && id.isNotEmpty).toSet();
                         final allScheduleIds = _dailySchedules.map((s) => s.id).toSet();
                         isPresent = allScheduleIds.isNotEmpty && attendedScheduleIds.containsAll(allScheduleIds);
                         if (isPresent && studentRecords.isNotEmpty) record = studentRecords.first;
                       } else {
                         record = _dailyAttendance.firstWhere(
                           (a) => a.studentId == student.id,
                           orElse: () => Attendance(id: '', studentId: '', studentName: '', studentNumber: '', classId: '', date: '', timestamp: DateTime(0), isPresent: false)
                         );
                         isPresent = record != null && record.id.isNotEmpty;
                       }
                     } else {
                       // Specific Subject
                       record = _dailyAttendance.firstWhere(
                         (a) => a.studentId == student.id && (a.scheduleId == _selectedScheduleId),
                         orElse: () => Attendance(id: '', studentId: '', studentName: '', studentNumber: '', classId: '', date: '', timestamp: DateTime(0), isPresent: false)
                       );
                       isPresent = record != null && record.id.isNotEmpty;
                     }
                   } catch (e) {
                     record = null;
                     isPresent = false;
                   }
                   
                   return DataRow(
                     cells: [
                       DataCell(Text(student.studentNumber, style: const TextStyle(fontWeight: FontWeight.w500))),
                       DataCell(Text(student.fullName)),
                       DataCell(
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           decoration: BoxDecoration(
                             color: isPresent ? Colors.green.shade100 : Colors.red.shade100,
                             borderRadius: BorderRadius.circular(20),
                           ),
                           child: Text(
                             isPresent ? 'Present' : 'Absent',
                             style: TextStyle(
                               color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
                               fontWeight: FontWeight.bold,
                               fontSize: 12,
                             ),
                           ),
                         ),
                       ),
                       DataCell(Text(
                         isPresent && record != null
                             ? _formatTime12Hour(record.timestamp)
                             : '-',
                         style: TextStyle(color: Colors.grey.shade600),
                       )),
                     ],
                   );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildClassDropdown() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (String value) {
        setState(() {
          _selectedClassId = value == 'all' ? null : value;
        });
        _loadStats(); // Trigger refresh on selection
      },
      itemBuilder: (context) {
        return [
           // 1. "All Classes" Option
           PopupMenuItem<String>(
              value: 'all',
              child: Row(
                children: [
                   Icon(
                     Icons.dashboard,
                     size: 16,
                     color: _selectedClassId == null ? Colors.blue.shade700 : Colors.blue.shade400
                   ),
                   const SizedBox(width: 8),
                   Text(
                     'All Classes',
                     style: TextStyle(
                       fontWeight: _selectedClassId == null ? FontWeight.bold : FontWeight.normal,
                       color: _selectedClassId == null ? Colors.blue.shade700 : Colors.black87,
                     )
                   )
                ]
              )
           ),
           // 2. Individual Class Options
           ..._instructorClasses.map((classGroup) {
              final isSelected = _selectedClassId == classGroup.id;
              return PopupMenuItem<String>(
                value: classGroup.id,
                child: Row(
                  children: [
                    Icon(
                      Icons.class_,
                      size: 16,
                      color: isSelected ? Colors.blue.shade700 : Colors.blue.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        classGroup.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.blue.shade700 : Colors.black87,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check, size: 16, color: Colors.blue.shade700),
                  ],
                ),
              );
            }).toList()
        ];
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _selectedClassId == null 
                   ? 'All Classes'
                   : _instructorClasses.firstWhere((c) => c.id == _selectedClassId, orElse: () => ClassGroup(id: '', name: 'Selected Class', instructorId: '')).name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: Colors.blue.shade700, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Today\'s Attendance',
            todayAttendanceCount.toString(),
            'Students Present',
            Icons.people,
            Colors.blue,
            null, // Removed static "+2 from yesterday"
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'This Week',
            weekAttendanceCount.toString(),
            'Total Check-ins',
            Icons.calendar_today,
            Colors.green,
            null, // Removed static "85% attendance rate"
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Average',
            (weekAttendanceCount / 7).toStringAsFixed(1),
            'Students/Day',
            Icons.trending_up,
            Colors.orange,
            null, // Removed static "Across 7 days"
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Photos Captured',
             weekAttendanceCount.toString(),
            'Total processed',
            Icons.photo_camera,
            Colors.purple,
             '$todayAttendanceCount today',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String? subtitle,
    IconData icon,
    Color color,
    String? footer,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 36, 
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                footer,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceChart() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Attendance Trend',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Student attendance over the past 7 days',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
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
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1, // Fix: Ensure distinct integer steps
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < dayLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              dayLabels[value.toInt()],
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
                // Add some padding to maxY so the line doesn't hit the top
                maxY: (weeklyAttendanceCounts.reduce((curr, next) => curr > next ? curr : next) * 1.25) + 5,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      weeklyAttendanceCounts.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        weeklyAttendanceCounts[index].toDouble(),
                      ),
                    ),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: Colors.blue,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withOpacity(0.3),
                          Colors.blue.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    // Calculate Quick Stats
    int maxIndex = 0;
    int minIndex = 0;
    int maxVal = -1;
    int minVal = 999999;
    
    for (int i = 0; i < weeklyAttendanceCounts.length; i++) {
      if (weeklyAttendanceCounts[i] > maxVal) {
        maxVal = weeklyAttendanceCounts[i];
        maxIndex = i;
      }
      if (weeklyAttendanceCounts[i] < minVal) {
        minVal = weeklyAttendanceCounts[i];
        minIndex = i;
      }
    }
    
    // If all zero
    if (maxVal == 0) {
      maxIndex = -1; 
      minIndex = -1;
    }

    // Calculate Average
    double total = weeklyAttendanceCounts.fold(0, (a, b) => a + b);
    double avg = total / 7;

    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildQuickStatItem(
            'Peak Day', 
            maxIndex != -1 ? dayLabels[maxIndex] : '-', 
            '$maxVal students', 
            Icons.star, 
            Colors.amber
          ),
          const SizedBox(height: 16),
          _buildQuickStatItem(
            'Lowest Day', 
             minIndex != -1 ? dayLabels[minIndex] : '-', 
            '$minVal students', 
            Icons.trending_down, 
            Colors.red
          ),
          const SizedBox(height: 16),
          _buildQuickStatItem(
            'Avg. Week', 
            '${total.toInt()} check-ins', 
            '${avg.toStringAsFixed(1)}/day', 
            Icons.analytics, 
            Colors.blue
          ),
          const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Model',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Ready',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(String title, String value, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivityItem('Camera capture', 'Photo saved successfully', '2 min ago', Icons.photo_camera, Colors.blue),
          _buildActivityItem('Student recognized', 'John Doe - 98% confidence', '15 min ago', Icons.face, Colors.green),
          _buildActivityItem('Attendance marked', '3 students checked in', '1 hour ago', Icons.check_circle, Colors.orange),
          _buildActivityItem('System ready', 'AI model initialized', '2 hours ago', Icons.settings, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentImagesPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Student Images',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 14, color: Colors.purple.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Captured photos and recognized faces',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          
          // Image grid placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Student photos will appear here',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gallery view of captured images and recognized students',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format DateTime to 12-hour format with AM/PM
  String _formatTime12Hour(DateTime dateTime) {
    int hour = dateTime.hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    
    // Convert to 12-hour format
    if (hour > 12) {
      hour = hour - 12;
    } else if (hour == 0) {
      hour = 12;
    }
    
    String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
