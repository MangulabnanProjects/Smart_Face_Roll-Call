import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/services/student_service.dart';
import '../../shared/services/class_service.dart';
import '../../shared/models/student.dart';
import '../../shared/models/class_group.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final StudentService _studentService = StudentService();
  final ClassService _classService = ClassService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              const Text(
                'Users',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'All registered students and instructors',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Students Section
              _buildStudentsSection(),

              const SizedBox(height: 48),

              // Instructors Section
              _buildInstructorsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsSection() {
    return StreamBuilder<List<ClassGroup>>(
      stream: _classService.getClassGroupsStream(),
      builder: (context, classSnapshot) {
        if (classSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (classSnapshot.hasError) {
          return Text('Error loading classes: ${classSnapshot.error}');
        }

        final classes = classSnapshot.data ?? [];

        if (classes.isEmpty) {
          return const Text('No classes found');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: classes.map((classGroup) {
            return _buildClassSection(classGroup);
          }).toList(),
        );
      },
    );
  }

  Widget _buildClassSection(ClassGroup classGroup) {
    return StreamBuilder<List<Student>>(
      stream: _studentService.getStudentsByClass(classGroup.id),
      builder: (context, studentSnapshot) {
        if (studentSnapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: CircularProgressIndicator(),
          );
        }

        final students = studentSnapshot.data ?? [];

        // Only show class if it has students
        if (students.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: ThemeData().copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: Colors.grey.shade50,
              collapsedBackgroundColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.folder, color: Colors.blue.shade700, size: 24),
              ),
              title: Text(
                classGroup.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${students.length} ${students.length == 1 ? "student" : "students"}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: students.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            student.firstName.isNotEmpty ? student.firstName[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                        title: Text(
                          student.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text('ID: ${student.studentNumber}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (student.email.isNotEmpty)
                              Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                            if (student.email.isNotEmpty) const SizedBox(width: 4),
                            if (student.email.isNotEmpty)
                              Text(
                                student.email,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructorsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Instructor_Information').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Error loading instructors: ${snapshot.error}');
        }

        final instructors = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructor Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.school, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    'Teachers / Instructors',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${instructors.length} ${instructors.length == 1 ? "instructor" : "instructors"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Instructor List
            if (instructors.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No instructors found'),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: instructors.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final instructor = instructors[index].data() as Map<String, dynamic>;
                    
                    // Try different field names for the instructor's name
                    String name = '';
                    if (instructor.containsKey('Full_Name') && instructor['Full_Name'] != null) {
                      name = instructor['Full_Name'];
                    } else if (instructor.containsKey('fullName') && instructor['fullName'] != null) {
                      name = instructor['fullName'];
                    } else if (instructor.containsKey('First_Name') && instructor.containsKey('Last_Name')) {
                      final firstName = instructor['First_Name'] ?? '';
                      final lastName = instructor['Last_Name'] ?? '';
                      name = '$firstName $lastName'.trim();
                    } else if (instructor.containsKey('firstName') && instructor.containsKey('lastName')) {
                      final firstName = instructor['firstName'] ?? '';
                      final lastName = instructor['lastName'] ?? '';
                      name = '$firstName $lastName'.trim();
                    } else if (instructor.containsKey('name')) {
                      name = instructor['name'] ?? '';
                    }
                    
                    if (name.isEmpty) name = 'Unknown';
                    
                    final email = instructor['email'] ?? instructor['Email'] ?? '';
                    final displayId = instructor['Instructor_ID'] ?? instructor['instructorId'] ?? instructors[index].id;
                    final authUid = instructors[index].id; // Firebase Auth UID is the document ID

                    return ListTile(
                      onTap: () => _showInstructorDetails(context, authUid, name, displayId),
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Text(
                          name.isNotEmpty && name != 'Unknown' ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('ID: $displayId'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (email.isNotEmpty) Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                          if (email.isNotEmpty) const SizedBox(width: 4),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _showInstructorDetails(BuildContext context, String authUid, String instructorName, String displayId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 900,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      instructorName.isNotEmpty ? instructorName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instructorName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Instructor ID: $displayId',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Content
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: const [
                          Tab(icon: Icon(Icons.folder), text: 'Classes'),
                          Tab(icon: Icon(Icons.calendar_month), text: 'Schedules'),
                        ],
                        labelColor: Colors.blue.shade700,
                        unselectedLabelColor: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Classes Tab
                            _buildInstructorClasses(authUid),
                            // Schedules Tab
                            _buildInstructorSchedules(authUid),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructorClasses(String instructorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ClassGroups')
          .where('instructorId', isEqualTo: instructorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final classes = snapshot.data?.docs ?? [];

        if (classes.isEmpty) {
          return const Center(
            child: Text(
              'No classes created yet',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final classData = classes[index].data() as Map<String, dynamic>;
            final className = classData['name'] ?? 'Unknown';
            final classId = classes[index].id;

            // Build collapsible folder for each class
            return StreamBuilder<List<Student>>(
              stream: _studentService.getStudentsByClass(classId),
              builder: (context, studentSnapshot) {
                final students = studentSnapshot.data ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Theme(
                    data: ThemeData().copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      backgroundColor: Colors.blue.shade50,
                      collapsedBackgroundColor: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Icon(Icons.folder, color: Colors.blue.shade600, size: 20),
                      title: Text(
                        className,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${students.length} ${students.length == 1 ? "student" : "students"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      children: students.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No students enrolled',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ]
                          : [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: students.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                                  itemBuilder: (context, idx) {
                                    final student = students[idx];
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.blue.shade100,
                                        child: Text(
                                          student.firstName.isNotEmpty ? student.firstName[0].toUpperCase() : '?',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        student.fullName,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        'ID: ${student.studentNumber}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInstructorSchedules(String instructorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Schedules')
          .where('instructorId', isEqualTo: instructorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final schedules = snapshot.data?.docs ?? [];

        if (schedules.isEmpty) {
          return const Center(
            child: Text(
              'No schedules created yet',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // Build calendar view
        final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        const startHour = 7;
        const endHour = 17;
        const hourHeight = 80.0;
        const timeColumnWidth = 80.0;

        return SingleChildScrollView(
          child: Column(
            children: [
              // Days header with gradient
              Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: timeColumnWidth,
                      child: Center(
                        child: Text(
                          'TIME',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    ...days.asMap().entries.map((entry) {
                      final day = entry.value;
                      return Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                day.substring(0, 3).toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Calendar grid with enhanced styling
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced time column
                    Container(
                      width: timeColumnWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade100, Colors.grey.shade50],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        border: Border(right: BorderSide(color: Colors.grey.shade300, width: 2)),
                      ),
                      child: Column(
                        children: List.generate(endHour - startHour + 1, (index) {
                          final hour = startHour + index;
                          return Container(
                            height: hourHeight,
                            alignment: Alignment.topCenter,
                            padding: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Text(
                              '${hour > 12 ? hour - 12 : hour}:00\n${hour >= 12 ? 'PM' : 'AM'}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Days columns with enhanced grid
                    Expanded(
                      child: SizedBox(
                        height: (endHour - startHour + 1) * hourHeight,
                        child: Row(
                          children: List.generate(7, (dayIndex) {
                            final daySessions = schedules
                                .where((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  return (data['dayIndex'] ?? 0) == dayIndex;
                                })
                                .toList();

                            // Alternating column colors for better readability
                            final isWeekend = dayIndex >= 5;
                            final bgColor = isWeekend 
                                ? Colors.orange.shade50.withOpacity(0.3)
                                : Colors.white;

                            return Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  border: Border(
                                    left: BorderSide(color: Colors.grey.shade300, width: 1),
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Grid lines
                                    Column(
                                      children: List.generate(endHour - startHour + 1, (index) {
                                        return Container(
                                          height: hourHeight,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),

                                    // Enhanced schedule blocks
                                    ...daySessions.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final title = data['title'] ?? 'Class';
                                      final subtitle = data['subtitle'] ?? '';
                                      final startH = data['startHour'] ?? 0;
                                      final startM = data['startMinute'] ?? 0;
                                      final endH = data['endHour'] ?? 0;
                                      final endM = data['endMinute'] ?? 0;

                                      final topOffset = ((startH - startHour) * hourHeight) + (startM / 60 * hourHeight);
                                      final duration = ((endH - startH) * hourHeight) + ((endM - startM) / 60 * hourHeight);

                                      // Color variations for different classes
                                      final colors = [
                                        [Colors.blue.shade400, Colors.blue.shade600],
                                        [Colors.purple.shade400, Colors.purple.shade600],
                                        [Colors.green.shade400, Colors.green.shade600],
                                        [Colors.orange.shade400, Colors.orange.shade600],
                                        [Colors.pink.shade400, Colors.pink.shade600],
                                      ];
                                      final colorPair = colors[title.hashCode % colors.length];

                                      return Positioned(
                                        top: topOffset,
                                        left: 6,
                                        right: 6,
                                        child: Container(
                                          height: duration,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: colorPair,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: [
                                              BoxShadow(
                                                color: colorPair[1].withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (subtitle.isNotEmpty)
                                                Text(
                                                  subtitle,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white.withOpacity(0.9),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')} - ${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
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
              ),
            ],
          ),
        );
      },
    );
  }
}
