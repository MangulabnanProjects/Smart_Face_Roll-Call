import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/class_session.dart';
import '../../shared/models/class_group.dart';
import '../../shared/models/student.dart';
import '../../shared/services/schedule_service.dart';
import '../../shared/services/class_service.dart';
import '../../shared/services/student_service.dart';

class WebManageScreen extends StatefulWidget {
  const WebManageScreen({super.key});

  @override
  State<WebManageScreen> createState() => _WebManageScreenState();
}

class _WebManageScreenState extends State<WebManageScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final ClassService _classService = ClassService();
  final StudentService _studentService = StudentService();
  
  User? _currentUser;
  String _instructorName = 'Instructor';
  
  // Class Groups State handled by StreamBuilder now
  String? _selectedClassId;

  // Config
  int get _startHour => 7; // 7 AM
  int get _endHour => 17; // 5 PM
  final double _hourHeight = 60.0;
  final double _timeColumnWidth = 80.0;
  final double _headerHeight = 50.0;

  final List<String> _days = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'
  ];

  // Colors Palette
  final List<Color> _colors = [
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.orange.shade100,
    Colors.purple.shade100,
    Colors.red.shade100,
    Colors.teal.shade100,
  ];

  // Available Rooms
  final List<String> _availableRooms = [
    '103',
    '105',
    '106',
    '107',
    '203',
    '204',
    '205',
    '206',
    'TESOL',
  ];


  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _instructorName = user.displayName ?? 'Instructor';
        });
      }
    }
  }

  void _addClassDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Class/Group'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Class Name (e.g. BSCS-4A)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _classService.addClassGroup(nameController.text);
                // Check if the Dialog itself is still active
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // Check for time overlap
  bool _hasTimeConflict(List<ClassSession> sessions, int day, TimeOfDay newStart, TimeOfDay newEnd, {String? excludeId}) {
    final newStartMins = newStart.hour * 60 + newStart.minute;
    final newEndMins = newEnd.hour * 60 + newEnd.minute;

    for (var session in sessions) {
      if (session.id == excludeId) continue;
      if (session.dayIndex == day) {
        final existingStartMins = session.startTime.hour * 60 + session.startTime.minute;
        final existingEndMins = session.endTime.hour * 60 + session.endTime.minute;

        // Check overlap: (StartA < EndB) && (EndA > StartB)
        if (newStartMins < existingEndMins && newEndMins > existingStartMins) {
          return true;
        }
      }
    }
    return false;
  }

  void _addSessionDialog(List<ClassSession> existingSessions) {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to add schedules.')));
      return;
    }

    final titleController = TextEditingController();
    String? selectedRoom; // Track selected room
    int selectedDay = 0;
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 11, minute: 0);
    Color selectedColor = _colors[0];
    String? selectedClassId; // New: selected class
    String errorMsg = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Class/Event'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Subject Code / Title', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRoom,
                    decoration: const InputDecoration(
                      labelText: 'Room Number',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select a room'),
                    items: _availableRooms.map((room) {
                      return DropdownMenuItem<String>(
                        value: room,
                        child: Text('Room $room'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedRoom = value);
                    },
                  ),
                  const SizedBox(height: 16),
                   // Read-only Instructor Name
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Instructor', 
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.black12,
                    ),
                    child: Text(
                      _instructorName, 
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // New: Class Selection Dropdown
                  StreamBuilder<QuerySnapshot>(
                    stream: _currentUser != null
                        ? FirebaseFirestore.instance
                            .collection('ClassGroups')
                            .where('instructorId', isEqualTo: _currentUser!.uid)
                            .snapshots()
                        : null,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final classes = snapshot.data!.docs;

                      if (classes.isEmpty) {
                        return const InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(),
                          ),
                          child: Text('No classes available'),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        value: selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Class (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select a class'),
                        items: classes.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final className = data['name'] ?? 'Unknown';
                          
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(className),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedClassId = value);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedDay,
                    decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
                    items: List.generate(7, (index) => DropdownMenuItem(
                      value: index,
                      child: Text(_days[index]),
                    )),
                    onChanged: (val) => setDialogState(() => selectedDay = val!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text('Start: ${start.format(context)}'),
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: start);
                            if (t != null) setDialogState(() => start = t);
                          },
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text('End: ${end.format(context)}'),
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: end);
                            if (t != null) setDialogState(() => end = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (errorMsg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(errorMsg, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 16),
                  const Text('Color Label'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _colors.map((c) => GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                      child: CircleAvatar(
                        backgroundColor: c,
                        radius: 16,
                        child: selectedColor == c ? const Icon(Icons.check, size: 16, color: Colors.black54) : null,
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                   // Validation
                  if (titleController.text.isEmpty || selectedRoom == null || selectedRoom!.isEmpty) {
                    setDialogState(() => errorMsg = 'Please fill in all fields');
                    return;
                  }

                  // Time Logic Validation
                  final startMins = start.hour * 60 + start.minute;
                  final endMins = end.hour * 60 + end.minute;
                  
                  if (endMins <= startMins) {
                     setDialogState(() => errorMsg = 'End time must be after start time');
                     return;
                  }

                  // 7 AM - 5 PM Constraint
                  if (start.hour < _startHour || end.hour > _endHour || (end.hour == _endHour && end.minute > 0)) {
                     setDialogState(() => errorMsg = 'Time must be between 7:00 AM and 5:00 PM');
                     return;
                  }

                  // Conflict Check
                  if (_hasTimeConflict(existingSessions, selectedDay, start, end)) {
                    setDialogState(() => errorMsg = 'Time overlaps with another schedule!');
                    return;
                  }

                  // Room Conflict Check
                  final roomConflict = await _scheduleService.checkRoomConflict(
                    room: selectedRoom!,
                    dayIndex: selectedDay,
                    startHour: start.hour,
                    startMinute: start.minute,
                    endHour: end.hour,
                    endMinute: end.minute,
                  );

                  if (roomConflict != null) {
                    final conflictStart = TimeOfDay(
                      hour: roomConflict['startHour'] as int,
                      minute: roomConflict['startMinute'] as int,
                    );
                    final conflictEnd = TimeOfDay(
                      hour: roomConflict['endHour'] as int,
                      minute: roomConflict['endMinute'] as int,
                    );
                    setDialogState(() => errorMsg = 
                      'Room ${roomConflict['room']} is already booked by ${roomConflict['instructorName']}\n'
                      'on ${_days[selectedDay]} from ${conflictStart.format(context)} to ${conflictEnd.format(context)}');
                    return;
                  }


                  // Create new session object
                  final newSession = ClassSession(
                    id: '', // Generated by Firestore
                    title: titleController.text,
                    subtitle: selectedRoom!,
                    dayIndex: selectedDay,
                    startTime: start,
                    endTime: end,
                    color: selectedColor,
                    instructorId: _currentUser!.uid,
                    instructorName: _instructorName, // Use the auto-filled name
                    classId: selectedClassId ?? '', // Use selected class or empty
                  );

                  await _scheduleService.addSchedule(newSession);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Add Block'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _editSessionDialog(ClassSession session, List<ClassSession> existingSessions) {
    if (_currentUser == null) return;
    
    final titleController = TextEditingController(text: session.title);
    String? selectedRoom = _availableRooms.contains(session.subtitle) ? session.subtitle : null; // Track selected room
    int selectedDay = session.dayIndex;
    TimeOfDay start = session.startTime;
    TimeOfDay end = session.endTime;
    Color selectedColor = session.color;
    String? selectedClassId = session.classId.isNotEmpty ? session.classId : null; // Pre-populate with current class
    String errorMsg = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Class/Event'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Subject Code / Title', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRoom,
                    decoration: const InputDecoration(
                      labelText: 'Room Number',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select a room'),
                    items: _availableRooms.map((room) {
                      return DropdownMenuItem<String>(
                        value: room,
                        child: Text('Room $room'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedRoom = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Instructor', border: OutlineInputBorder(), filled: true, fillColor: Colors.black12),
                    child: Text(session.instructorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  
                  // Class Selection Dropdown
                  StreamBuilder<QuerySnapshot>(
                    stream: _currentUser != null
                        ? FirebaseFirestore.instance
                            .collection('ClassGroups')
                            .where('instructorId', isEqualTo: _currentUser!.uid)
                            .snapshots()
                        : null,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 60,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final classes = snapshot.data!.docs;

                      if (classes.isEmpty) {
                        return const InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(),
                          ),
                          child: Text('No classes available'),
                        );
                      }

                      // Only use selectedClassId if it's actually in the list
                      final availableIds = classes.map((doc) => doc.id).toList();
                      final currentValue = (selectedClassId != null && availableIds.contains(selectedClassId))
                          ? selectedClassId
                          : null;

                      return DropdownButtonFormField<String>(
                        value: currentValue,
                        decoration: const InputDecoration(
                          labelText: 'Class (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select a class'),
                        items: classes.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final className = data['name'] ?? 'Unknown';
                          
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(className),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedClassId = value;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedDay,
                    decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
                    items: List.generate(7, (index) => DropdownMenuItem(value: index, child: Text(_days[index]))),
                    onChanged: (val) => setDialogState(() => selectedDay = val!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text('Start: ${start.format(context)}'),
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: start);
                            if (t != null) setDialogState(() => start = t);
                          },
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text('End: ${end.format(context)}'),
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: end);
                            if (t != null) setDialogState(() => end = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (errorMsg.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 10), child: Text(errorMsg, style: const TextStyle(color: Colors.red))),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: _colors.map((c) => GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = c),
                       child: CircleAvatar(backgroundColor: c, radius: 16, child: selectedColor == c ? const Icon(Icons.check, size: 16, color: Colors.black54) : null),
                    )).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Schedule?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    )
                  );
                  if (confirm == true) {
                    await _scheduleService.deleteSchedule(session.id);
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Delete'),
              ),
              ElevatedButton(
                onPressed: () async {
                   if (titleController.text.isEmpty || selectedRoom == null || selectedRoom!.isEmpty) {
                    setDialogState(() => errorMsg = 'Please fill in all fields');
                    return;
                  }
                  final startMins = start.hour * 60 + start.minute;
                  final endMins = end.hour * 60 + end.minute;
                  if (endMins <= startMins) {
                     setDialogState(() => errorMsg = 'End time must be after start time');
                     return;
                  }

                  // 7 AM - 5 PM Constraint
                  if (start.hour < _startHour || end.hour > _endHour || (end.hour == _endHour && end.minute > 0)) {
                     setDialogState(() => errorMsg = 'Time must be between 7:00 AM and 5:00 PM');
                     return;
                  }
                  
                  if (_hasTimeConflict(existingSessions, selectedDay, start, end, excludeId: session.id)) {
                    setDialogState(() => errorMsg = 'Time overlaps with another schedule!');
                    return;
                  }

                  // Room Conflict Check
                  final roomConflict = await _scheduleService.checkRoomConflict(
                    room: selectedRoom!,
                    dayIndex: selectedDay,
                    startHour: start.hour,
                    startMinute: start.minute,
                    endHour: end.hour,
                    endMinute: end.minute,
                    excludeScheduleId: session.id,
                  );

                  if (roomConflict != null) {
                    final conflictStart = TimeOfDay(
                      hour: roomConflict['startHour'] as int,
                      minute: roomConflict['startMinute'] as int,
                    );
                    final conflictEnd = TimeOfDay(
                      hour: roomConflict['endHour'] as int,
                      minute: roomConflict['endMinute'] as int,
                    );
                    setDialogState(() => errorMsg = 
                      'Room ${roomConflict['room']} is already booked by ${roomConflict['instructorName']}\n'
                      'on ${_days[selectedDay]} from ${conflictStart.format(context)} to ${conflictEnd.format(context)}');
                    return;
                  }


                  final updatedSession = ClassSession(
                    id: session.id,
                    title: titleController.text,
                    subtitle: selectedRoom!,
                    dayIndex: selectedDay,
                    startTime: start,
                    endTime: end,
                    color: selectedColor,
                    instructorId: session.instructorId,
                    instructorName: session.instructorName,
                    classId: selectedClassId ?? '', // Use updated selected class
                  );

                  await _scheduleService.updateSchedule(updatedSession);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) return const Center(child: Text('Please log in'));

    return StreamBuilder<List<ClassSession>>(
      // Fetch ALL schedules for this instructor
      stream: _scheduleService.getSchedulesStream(_currentUser!.uid), 
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading schedules: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final sessions = snapshot.data ?? [];

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addSessionDialog(sessions), 
            label: const Text('Add Schedule'),
            icon: const Icon(Icons.add),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // My Classes Section
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My Classes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 110,
                        child: StreamBuilder<List<ClassGroup>>(
                          stream: _classService.getClassGroupsStream(),
                          builder: (context, classSnapshot) {
                            if (classSnapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error, color: Colors.red),
                                    Text('Error: ${classSnapshot.error}'),
                                    ElevatedButton(
                                      onPressed: () => setState(() {}),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            
                            if (classSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            final groups = classSnapshot.data ?? [];

                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: groups.length + 1,
                              itemBuilder: (context, index) {
                                if (index == groups.length) {
                                  return _buildAddClassCard();
                                }
                                return _buildFolderCard(groups[index]);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // Calendar Section
                _buildCalendar(sessions),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildCalendar(List<ClassSession> sessions) {
    // Total height of the grid content
    final totalHeight = (_endHour - _startHour + 1) * _hourHeight;

    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                    'Schedule Management',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Manage visual weekly timetable',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
              // Button hidden here, moved to FAB for easier access in Scaffold
            ],
          ),
        ),
        
        const Divider(height: 1),

        // Main Timetable Area
        Column(
          children: [
            // 1. Sticky Header (Days)
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(width: _timeColumnWidth, child: const Center(child: Text('TIME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                  ..._days.map((day) => Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Text(
                        day,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  )),
                ],
              ),
            ),

            // 2. Calendar Grid Body (Times + Grid)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Time Labels Column
                  SizedBox(
                    width: _timeColumnWidth,
                    height: totalHeight,
                    child: Column(
                      children: List.generate(_endHour - _startHour + 1, (index) {
                        final hour = _startHour + index;
                        return Container(
                          height: _hourHeight,
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            color: Colors.white,
                          ),
                          child: Text(
                            '${hour > 12 ? hour - 12 : hour}:00 ${hour >= 12 ? 'PM' : 'AM'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Day Columns Grid
                  Expanded(
                    child: SizedBox(
                      height: totalHeight,
                      child: Row(
                        children: List.generate(7, (dayIndex) {
                          final daySessions = sessions.where((s) => s.dayIndex == dayIndex).toList();
                          
                          return Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(left: BorderSide(color: Colors.grey.shade200)),
                              ),
                              child: Stack(
                                  children: [
                                    // Background Grid Lines
                                    Column(
                                      children: List.generate(_endHour - _startHour + 1, (index) {
                                        return Container(
                                          height: _hourHeight,
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                                          ),
                                        );
                                      }),
                                    ),

                                    // Event Blocks
                                    ...daySessions.map((session) => _buildSessionCard(session, sessions)),
                                  ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
  }

  // --- Folder Widgets ---

  Widget _buildFolderCard(ClassGroup group) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStudentManager(group),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.folder, size: 40, color: Colors.blue),
                Text(
                  group.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('Manage Students', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddClassCard() {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _addClassDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, size: 32, color: Colors.grey),
                SizedBox(height: 8),
                Text('New Class', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStudentManager(ClassGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.folder_open, color: Colors.blue),
            const SizedBox(width: 8),
            Text(group.name),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            children: [
              // Student List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Enrolled Students', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ElevatedButton.icon(
                    onPressed: () => _addStudentDialog(context, group.id),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Student'),
                  ),
                ],
              ),
              const Divider(),
              
              // Student List Stream
              Expanded(
                child: StreamBuilder<List<Student>>(
                  stream: _studentService.getStudentsByClass(group.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    final students = snapshot.data ?? [];
                    if (students.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('No students yet.', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text(student.firstName.isNotEmpty ? student.firstName[0] : '?')),
                          title: Text('${student.firstName} ${student.lastName}'),
                          subtitle: Text('ID: ${student.studentNumber} | ${student.email}'),
                          onTap: () => _showStudentDetails(context, student),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              // Confirm delete
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove Student?'),
                                  content: Text('Remove ${student.firstName} from this class?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _studentService.deleteStudent(student.id);
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showStudentDetails(BuildContext context, Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 500,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with avatar
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        student.firstName.isNotEmpty ? student.firstName[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue.shade600),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Student ID: ${student.studentNumber}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Student Information Cards
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.cake, 'Birthday', '${student.birthday.toLocal()}'.split(' ')[0]),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.email, 'Email', student.email.isEmpty ? 'Not provided' : student.email),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.phone, 'Phone', student.phoneNumber.isEmpty ? 'Not provided' : student.phoneNumber),
                  ],
                ),
              ),
            ],
          ),
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
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade600, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addStudentDialog(BuildContext parentContext, String classId) {
    final formKey = GlobalKey<FormState>();
    final studentNoController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController(); // Split name or just Full Name? User said FullName but I split in model. Keeping FullName in logic for simplicity if requested. WAIT, Code uses FullName in model? 
    // Checking model: `fullName`. Okay, I will use `fullName`.
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    DateTime birthday = DateTime.now();

    showDialog(
      context: parentContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Student'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: studentNoController,
                          decoration: const InputDecoration(labelText: 'Student Number', prefixIcon: Icon(Icons.badge)),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                           // Optional validation for email format
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Birthday'),
                          subtitle: Text('${birthday.toLocal()}'.split(' ')[0]),
                          leading: const Icon(Icons.cake),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: birthday,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => birthday = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newStudent = Student(
                        id: '', // Firestore generates this if we use .add, but model expects one. 
                        // Service uses .add() which ignores 'id' field in map. 
                        // Wait, Service uses .add(student.toMap()). Model needs id. 
                        // Best practice: let service return ID or ignore ID for creating.
                        // I will pass empty string for now, Firestore doc ID is separate.
                        studentNumber: studentNoController.text,
                        fullName: fullNameController.text,
                        birthday: birthday,
                        email: emailController.text,
                        phoneNumber: phoneController.text,
                        classId: classId,
                      );
                      
                      await _studentService.addStudent(newStudent);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Student'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildSessionCard(ClassSession session, List<ClassSession> allSessions) {
    // Calculate vertical positioning
    final startMinutes = (session.startTime.hour * 60) + session.startTime.minute;
    final endMinutes = (session.endTime.hour * 60) + session.endTime.minute;
    final gridStartMinutes = _startHour * 60;
    
    final topOffset = ((startMinutes - gridStartMinutes) / 60) * _hourHeight;
    final durationHours = (endMinutes - startMinutes) / 60;
    final height = durationHours * _hourHeight;

    return Positioned(
      top: topOffset,
      left: 2, // Tiny margin
      right: 2,
      height: height - 2, // Tiny margin
      child: GestureDetector(
        onTap: () => _editSessionDialog(session, allSessions),
        child: Container(
          padding: const EdgeInsets.all(6), // Reduced from 8 to give more space
          decoration: BoxDecoration(
            color: session.color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject Code / Title
              Text(
                session.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), // Reduced from 13
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Class Name (if available) - on separate line
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
                        return Text(
                          className,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), // Reduced from 11
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
              const SizedBox(height: 2), // Reduced from 4
              Text(
                session.subtitle,
                style: const TextStyle(fontSize: 10, height: 1.2), // Reduced from 11
                maxLines: 2, // Reduced from 3 to save space
                overflow: TextOverflow.ellipsis,
              ),
              if (session.instructorName.isNotEmpty) // Safety check
                Text(
                  session.instructorName,
                  style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic), // Reduced from 10
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
