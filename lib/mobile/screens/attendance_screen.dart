import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/attendance.dart';
import '../../shared/services/attendance_service.dart';
import 'package:intl/intl.dart';

/// Attendance screen displaying records in traditional sheet format
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String selectedClassId = '';
  String className = ''; // NEW: Class name (e.g., "BSCS-4A")
  String? selectedScheduleId; // NEW: Selected schedule filter
  String selectedDate = Attendance.formatDate(DateTime.now());
  List<Map<String, dynamic>> allStudents = [];
  List<Map<String, dynamic>> classSchedules = []; // NEW: List of schedules for this class
  List<Attendance> attendanceRecords = [];
  List<String> relatedClassIds = []; // NEW: List of all class IDs with same name
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() => isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      // Get student's class ID
      final studentDoc = await FirebaseFirestore.instance
          .collection('Students')
          .doc(user.uid)
          .get();

      if (!studentDoc.exists) {
        setState(() => isLoading = false);
        return;
      }

      final studentData = studentDoc.data()!;
      final classId = studentData['classId'] ?? '';

      if (classId.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      setState(() => selectedClassId = classId);

      // Get class name from ClassGroups
      final classDoc = await FirebaseFirestore.instance
          .collection('ClassGroups')
          .doc(classId)
          .get();
      
      final classGroupName = classDoc.data()?['name'] ?? '';

      // Find ALL ClassGroups with the same name (e.g., "BSCS-4A" from different instructors)
      List<String> matchingClassIds = [classId];
      if (classGroupName.isNotEmpty) {
        final relatedClassesSnapshot = await FirebaseFirestore.instance
            .collection('ClassGroups')
            .where('name', isEqualTo: classGroupName)
            .get();
        
        matchingClassIds = relatedClassesSnapshot.docs.map((doc) => doc.id).toList();
      }

      // Get schedules for ANY of these matching classes
      // Note: 'whereIn' is limited to 10 values in Firestore. 
      // If > 10, we might need multiple queries, but for now assuming < 10 instructors per class.
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('Schedules')
          .where('classId', whereIn: matchingClassIds.take(10).toList())
          .get();

      final schedules = schedulesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Unnamed',
          'dayIndex': data['dayIndex'] ?? 0,
        };
      }).toList();

      // Get all students in this class
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('Students')
          .where('classId', isEqualTo: classId)
          .get();

      final students = studentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'studentNumber': data['studentNumber'] ?? '',
          'fullName': data['fullName'] ?? '',
        };
      }).toList();

      // Sort by student number
      students.sort((a, b) => a['studentNumber'].compareTo(b['studentNumber']));

      setState(() {
        className = classGroupName;
        classSchedules = schedules;
        allStudents = students;
        relatedClassIds = matchingClassIds; // Store for attendance query
        isLoading = false;
      });

      // Load attendance for today
      _loadAttendance();
    } catch (e) {
      debugPrint('Error loading student data: $e');
      setState(() => isLoading = false);
    }
  }

  void _loadAttendance() {
    // This will be updated in real-time via stream
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = Attendance.formatDate(picked);
        selectedScheduleId = null; // Reset filter when date changes to prevent mismatch
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Calculate today's schedules for logic and header
    final selectedDateTime = DateTime.parse(selectedDate);
    final dayIndex = selectedDateTime.weekday - 1;
    final todaysSchedules = classSchedules
        .where((s) => s['dayIndex'] == dayIndex)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Sheet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : selectedClassId.isEmpty
              ? const Center(
                  child: Text('No class assigned'),
                )
              : Column(
                  children: [
                    // Header Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.shade50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Class:',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    className.isEmpty ? selectedClassId : className,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Date:',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM d, y').format(selectedDateTime),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Schedule filter dropdown (Filtered by day)
                          if (todaysSchedules.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Filter by Schedule',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              value: selectedScheduleId,
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Schedules (Daily Summary)'),
                                ),
                                ...todaysSchedules.map((schedule) {
                                  return DropdownMenuItem<String>(
                                    value: schedule['id'],
                                    child: Text(schedule['title']),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() => selectedScheduleId = value);
                              },
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                                  SizedBox(width: 8),
                                  Text('No classes scheduled for this date.', style: TextStyle(color: Colors.orange)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.grey.shade200,
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('Present', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),

                    // Attendance List
                    Expanded(
                      child: StreamBuilder<List<Attendance>>(
                        stream: AttendanceService().getAttendanceForClassesAndDate(
                          relatedClassIds.isEmpty ? [selectedClassId] : relatedClassIds,
                          selectedDate,
                        ),
                        builder: (context, snapshot) {
                          var attendanceList = snapshot.data ?? [];
                          Set<String> presentStudentIds = {};
                          
                          // Determine marked students based on filter
                          if (selectedScheduleId != null) {
                            // Single Schedule View: Check if attended THIS schedule
                            attendanceList = attendanceList
                                .where((a) => a.scheduleId == selectedScheduleId)
                                .toList();
                            presentStudentIds = attendanceList.map((a) => a.studentId).toSet();
                          } else {
                             // All Schedules View: Check if attended ALL schedules for today
                             final dayIndex = DateTime.parse(selectedDate).weekday - 1;
                             final todaysScheduleIds = classSchedules
                                 .where((s) => s['dayIndex'] == dayIndex)
                                 .map((s) => s['id'])
                                 .toSet();
                             
                             if (todaysScheduleIds.isNotEmpty) {
                               // Group by student
                               final studentAttendanceMap = <String, Set<String>>{};
                               for (var a in attendanceList) {
                                  if (a.scheduleId != null) {
                                    studentAttendanceMap.putIfAbsent(a.studentId, () => {}).add(a.scheduleId!);
                                  }
                               }
                               
                               // Verify completeness
                               for (var entry in studentAttendanceMap.entries) {
                                  if (todaysScheduleIds.every((id) => entry.value.contains(id))) {
                                    presentStudentIds.add(entry.key);
                                  }
                               }
                             }
                             // If no schedules today, presentStudentIds remains empty (or logic choice)
                          }

                          return ListView.separated(
                            itemCount: allStudents.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final student = allStudents[index];
                              final isPresent = presentStudentIds.contains(student['id']);

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                color: isPresent ? Colors.green.shade50 : Colors.transparent,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(student['studentNumber'], style: const TextStyle(fontSize: 14)),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(student['fullName'], style: const TextStyle(fontSize: 14)),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: isPresent
                                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                            : const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Summary Footer
                    StreamBuilder<List<Attendance>>(
                      stream: AttendanceService().getAttendanceForClassesAndDate(
                        relatedClassIds.isEmpty ? [selectedClassId] : relatedClassIds,
                        selectedDate,
                      ),
                      builder: (context, snapshot) {
                        var attendanceList = snapshot.data ?? [];
                        Set<String> presentStudentIds = {};

                        // Determine marked students based on filter (Same logic as above)
                        if (selectedScheduleId != null) {
                          // Single Schedule View
                          attendanceList = attendanceList
                              .where((a) => a.scheduleId == selectedScheduleId)
                              .toList();
                           presentStudentIds = attendanceList.map((a) => a.studentId).toSet();
                        } else {
                           // All Schedules View: Check if attended ALL schedules for today
                           final dayIndex = DateTime.parse(selectedDate).weekday - 1;
                           final todaysScheduleIds = classSchedules
                               .where((s) => s['dayIndex'] == dayIndex)
                               .map((s) => s['id'])
                               .toSet();
                           
                           if (todaysScheduleIds.isNotEmpty) {
                             final studentAttendanceMap = <String, Set<String>>{};
                             for (var a in attendanceList) {
                                if (a.scheduleId != null) {
                                  studentAttendanceMap.putIfAbsent(a.studentId, () => {}).add(a.scheduleId!);
                                }
                             }
                             
                             for (var entry in studentAttendanceMap.entries) {
                                if (todaysScheduleIds.every((id) => entry.value.contains(id))) {
                                  presentStudentIds.add(entry.key);
                                }
                             }
                           }
                        }

                        final presentCount = presentStudentIds.length;
                        final totalCount = allStudents.length;
                        final percentage = totalCount > 0
                            ? (presentCount / totalCount * 100).toStringAsFixed(1)
                            : '0.0';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                'Present',
                                presentCount.toString(),
                                Colors.green,
                              ),
                              _buildSummaryItem(
                                'Total',
                                totalCount.toString(),
                                Colors.blue,
                              ),
                              _buildSummaryItem(
                                'Rate',
                                '$percentage%',
                                Colors.orange,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
