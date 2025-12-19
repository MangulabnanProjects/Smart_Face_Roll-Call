import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/models/attendance.dart';

class TodayClassesDialog extends StatefulWidget {
  const TodayClassesDialog({super.key});

  @override
  State<TodayClassesDialog> createState() => _TodayClassesDialogState();
}

class _TodayClassesDialogState extends State<TodayClassesDialog> {
  bool isLoading = true;
  List<Map<String, dynamic>> classBreakdown = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClassBreakdown();
  }

  Future<void> _loadClassBreakdown() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // 1. Get User's Class ID
      final studentDoc = await FirebaseFirestore.instance.collection('Students').doc(user.uid).get();
      final classId = studentDoc.data()?['classId'] as String? ?? '';
      
      if (classId.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
            errorMessage = 'No class assigned.';
          });
        }
        return;
      }

      // 2. Get Related Class IDs (same name)
      final List<String> relatedIds = await _getRelatedClassIds(classId);

      // 3. Get Today's Schedules
      final now = DateTime.now();
      final dayIndex = now.weekday - 1; // Mon=0
      
      final schedulesQuery = await FirebaseFirestore.instance
          .collection('Schedules')
          .where('classId', whereIn: relatedIds.take(10).toList())
          .where('dayIndex', isEqualTo: dayIndex)
          .get();

      final schedules = schedulesQuery.docs.map((doc) => {
        'id': doc.id,
        'title': doc.data()['title'] ?? 'Unknown',
        'startTime': '${doc.data()['startHour']}:${doc.data()['startMinute'].toString().padLeft(2, '0')}',
        'endTime': '${doc.data()['endHour']}:${doc.data()['endMinute'].toString().padLeft(2, '0')}',
        'startHour': doc.data()['startHour'] as int? ?? 0,
        'count': 0, // Placeholder
      }).toList();
      
      // Sort by time
      schedules.sort((a, b) => (a['startHour'] as int).compareTo(b['startHour'] as int));

      if (schedules.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
            classBreakdown = [];
          });
        }
        return;
      }

      // 4. Get Today's Attendance for these classes
      final dateStr = Attendance.formatDate(now);
      
      // We want TOTAL students present, not just the current user.
      // So queries need to be by classId (and its related IDs).
      
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('Attendance')
          .where('classId', whereIn: relatedIds.take(10).toList())
          .where('date', isEqualTo: dateStr)
          .get();

      final attendanceDocs = attendanceQuery.docs;

      // 5. Correlate Attendance to Schedules
      for (var schedule in schedules) {
        final scheduleId = schedule['id'];
        
        // Count unique studentIds for this schedule
        final presentStudentIds = attendanceDocs
            .where((doc) => doc.data()['scheduleId'] == scheduleId)
            .map((doc) => doc.data()['studentId'] as String)
            .toSet();
            
        schedule['count'] = presentStudentIds.length;
      }

      if (mounted) {
        setState(() {
          classBreakdown = schedules;
          isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Error loading breakdown: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load data.';
        });
      }
    }
  }

  Future<List<String>> _getRelatedClassIds(String classId) async {
    List<String> relatedClassIds = [classId];
    try {
      final classDoc = await FirebaseFirestore.instance.collection('ClassGroups').doc(classId).get();
      final className = classDoc.data()?['name'];
      
      if (className != null && className.isNotEmpty) {
         final snapshot = await FirebaseFirestore.instance
            .collection('ClassGroups')
            .where('name', isEqualTo: className)
            .get();
         relatedClassIds = snapshot.docs.map((d) => d.id).toList();
      }
    } catch (_) {}
    return relatedClassIds;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Classes",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Attendance breakdown per subject",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
            else if (classBreakdown.isEmpty)
              const Center(child: Text("No classes scheduled for today."))
            else
              ListView.separated(
                shrinkWrap: true,
                itemCount: classBreakdown.length,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (context, index) {
                  final item = classBreakdown[index];
                  final count = item['count'] as int;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.class_, color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                '${item['startTime']} - ${item['endTime']}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: count > 0 ? Colors.green.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: count > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: count > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
