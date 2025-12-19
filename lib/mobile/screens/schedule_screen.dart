import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/models/class_session.dart';

/// Read-only schedule viewer for students to see their instructors' schedules
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final int _startHour = 7;
  final int _endHour = 22;
  final double _hourHeight = 80.0;
  
  String? _selectedInstructorId; // null means "All Instructors"
  bool _isInstructorSelectorExpanded = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        centerTitle: true,
      ),
      body: currentUser == null
          ? const Center(child: Text('Please log in to view schedules'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Students')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, studentSnapshot) {
                // Loading state
                if (studentSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Error state
                if (studentSnapshot.hasError) {
                  return Center(
                    child: Text('Error loading student data: ${studentSnapshot.error}'),
                  );
                }

                // No data
                if (!studentSnapshot.hasData || !studentSnapshot.data!.exists) {
                  return const Center(child: Text('Student data not found'));
                }

                final studentData = studentSnapshot.data!.data() as Map<String, dynamic>;
                final instructorIds = (studentData['instructorIds'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ?? [];
                final studentClassId = studentData['classId'] as String? ?? '';

                print('DEBUG: Student instructorIds: $instructorIds'); // Debug
                print('DEBUG: Student classId: $studentClassId'); // Debug

                if (instructorIds.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No instructors assigned.\nPlease contact your administrator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                }

                // Fetch schedules for all instructors
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Schedules')
                      .where('instructorId', whereIn: instructorIds)
                      .snapshots(),
                  builder: (context, scheduleSnapshot) {
                    // Loading state
                    if (scheduleSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Error state
                    if (scheduleSnapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'Error loading schedules: ${scheduleSnapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    // No data
                    if (!scheduleSnapshot.hasData) {
                      return const Center(child: Text('No schedule data available'));
                    }

                    print('DEBUG: Found ${scheduleSnapshot.data!.docs.length} schedule documents'); // Debug

                    final schedules = scheduleSnapshot.data!.docs
                        .map((doc) {
                          try {
                            final data = doc.data() as Map<String, dynamic>;
                            return ClassSession.fromMap(data, doc.id);
                          } catch (e) {
                            print('DEBUG: Error parsing schedule ${doc.id}: $e'); // Debug
                            return null;
                          }
                        })
                        .where((session) => session != null)
                        .cast<ClassSession>()
                        .toList();

                    print('DEBUG: Parsed ${schedules.length} schedules successfully'); // Debug

                    // Filter schedules by selected instructor
                    final filteredSchedules = _selectedInstructorId == null
                        ? schedules
                        : schedules.where((s) => s.instructorId == _selectedInstructorId).toList();

                    return Column(
                      children: [
                        // Instructor Selector Card
                        _buildInstructorSelector(instructorIds),
                        // Schedule View
                        Expanded(
                          child: filteredSchedules.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Text(
                                      'No schedules for selected instructor',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                )
                              : _buildScheduleView(filteredSchedules, studentClassId),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildInstructorSelector(List<String> instructorIds) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.people),
            title: Text(
              _selectedInstructorId == null
                  ? 'All Instructors'
                  : 'Filter Active',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _selectedInstructorId == null
                  ? 'Showing all schedules'
                  : 'Tap to change',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              icon: Icon(
                _isInstructorSelectorExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
              ),
              onPressed: () {
                setState(() {
                  _isInstructorSelectorExpanded = !_isInstructorSelectorExpanded;
                });
              },
            ),
          ),
          if (_isInstructorSelectorExpanded)
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Instructor:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // "All" chip
                      FilterChip(
                        label: const Text('All Instructors'),
                        selected: _selectedInstructorId == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedInstructorId = null;
                          });
                        },
                        selectedColor: Colors.blue.shade100,
                      ),
                      // Individual instructor chips
                      ...instructorIds.map((instructorId) {
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('Instructor_Information')
                              .doc(instructorId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            String instructorName = 'Loading...';
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              instructorName = data['Full_Name'] ??
                                  data['fullName'] ??
                                  '${data['First_Name'] ?? ''} ${data['Last_Name'] ?? ''}'.trim();
                              if (instructorName.isEmpty) instructorName = 'Unknown';
                            }

                            return FilterChip(
                              label: Text(instructorName),
                              selected: _selectedInstructorId == instructorId,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedInstructorId = selected ? instructorId : null;
                                });
                              },
                              selectedColor: Colors.blue.shade100,
                            );
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleView(List<ClassSession> schedules, String studentClassId) {
    // Fetch student's class name once at this level
    return StreamBuilder<DocumentSnapshot>(
      stream: studentClassId.isNotEmpty
          ? FirebaseFirestore.instance
              .collection('ClassGroups')
              .doc(studentClassId)
              .snapshots()
          : null,
      builder: (context, studentClassSnapshot) {
        String studentClassName = '';
        if (studentClassSnapshot.hasData && studentClassSnapshot.data!.exists) {
          final data = studentClassSnapshot.data!.data() as Map<String, dynamic>;
          studentClassName = data['name'] ?? '';
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 1.5,
            child: Column(
              children: [
                // Day headers
                _buildDayHeaders(),
                // Schedule grid
                Expanded(
                  child: _buildScheduleGrid(schedules, studentClassName),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayHeaders() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // Time column header
          Container(
            width: 60,
            alignment: Alignment.center,
            child: const Text(
              'Time',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          // Day headers
          ...List.generate(7, (index) {
            return Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  _days[index].substring(0, 3), // Mon, Tue, etc.
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScheduleGrid(List<ClassSession> schedules, String studentClassName) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time labels column
          _buildTimeColumn(),
          // Day columns with schedules
          ...List.generate(7, (dayIndex) {
            final daySessions = schedules.where((s) => s.dayIndex == dayIndex).toList();
            return Expanded(
              child: _buildDayColumn(dayIndex, daySessions, studentClassName),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeColumn() {
    return Container(
      width: 60,
      child: Column(
        children: List.generate(_endHour - _startHour, (index) {
          final hour = _startHour + index;
          return Container(
            height: _hourHeight,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${hour % 12 == 0 ? 12 : hour % 12} ${hour < 12 ? 'AM' : 'PM'}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(int dayIndex, List<ClassSession> sessions, String studentClassName) {
    final totalHeight = (_endHour - _startHour) * _hourHeight;
    
    return SizedBox(
      height: totalHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Stack(
          children: [
            // Hour grid lines
            ...List.generate(_endHour - _startHour, (index) {
              return Positioned(
                top: index * _hourHeight,
                left: 0,
                right: 0,
                child: Container(
                  height: _hourHeight,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
              );
            }),
            // Schedule blocks
            ...sessions.map((session) => _buildSessionBlock(session, studentClassName)),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionBlock(ClassSession session, String studentClassName) {
    final startMinutes = (session.startTime.hour * 60) + session.startTime.minute;
    final endMinutes = (session.endTime.hour * 60) + session.endTime.minute;
    final gridStartMinutes = _startHour * 60;

    final topOffset = ((startMinutes - gridStartMinutes) / 60) * _hourHeight;
    final durationHours = (endMinutes - startMinutes) / 60;
    final height = durationHours * _hourHeight;

    return Positioned(
      top: topOffset,
      left: 2,
      right: 2,
      height: height - 4,
      child: StreamBuilder<DocumentSnapshot>(
        stream: session.classId.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('ClassGroups')
                .doc(session.classId)
                .snapshots()
            : null,
        builder: (context, sessionClassSnapshot) {
          String sessionClassName = '';
          if (sessionClassSnapshot.hasData && sessionClassSnapshot.data!.exists) {
            final data = sessionClassSnapshot.data!.data() as Map<String, dynamic>;
            sessionClassName = data['name'] ?? '';
          }

          // Check if this schedule's class name matches student's class name
          final isMyClass = sessionClassName.isNotEmpty &&
              studentClassName.isNotEmpty &&
              sessionClassName == studentClassName;

          return GestureDetector(
            onTap: () => _showSessionDetails(session),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: session.color.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isMyClass ? Colors.amber.shade700 : Colors.white,
                  width: isMyClass ? 2 : 1,
                ),
                boxShadow: isMyClass
                    ? [
                        BoxShadow(
                          color: Colors.amber.shade300.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sessionClassName.isNotEmpty)
                    Text(
                      sessionClassName,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    session.subtitle,
                    style: const TextStyle(fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSessionDetails(ClassSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(session.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (session.classId.isNotEmpty)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ClassGroups')
                    .doc(session.classId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final className = data['name'] ?? '';
                    if (className.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.class_, size: 18),
                            const SizedBox(width: 8),
                            Text(className, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            _buildInfoRow(Icons.room, 'Room', session.subtitle),
            _buildInfoRow(Icons.person, 'Instructor', session.instructorName),
            _buildInfoRow(Icons.calendar_today, 'Day', _days[session.dayIndex]),
            _buildInfoRow(
              Icons.access_time,
              'Time',
              '${session.startTime.format(context)} - ${session.endTime.format(context)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
