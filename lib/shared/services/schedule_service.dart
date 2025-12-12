import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_session.dart';

class ScheduleService {
  final CollectionReference _schedulesRef = 
      FirebaseFirestore.instance.collection('Schedules');

  // Add new schedule
  Future<void> addSchedule(ClassSession session) async {
    // We don't use the session.id here because Firestore generates a new one
    await _schedulesRef.add(session.toMap());
  }

  // Update existing schedule
  Future<void> updateSchedule(ClassSession session) async {
    await _schedulesRef.doc(session.id).update(session.toMap());
  }

  // Delete schedule
  Future<void> deleteSchedule(String scheduleId) async {
    await _schedulesRef.doc(scheduleId).delete();
  }

  // Stream of schedules filtered by Instructor and opt. Class
  Stream<List<ClassSession>> getSchedulesStream(String instructorId, {String? classId}) {
    Query query = _schedulesRef.where('instructorId', isEqualTo: instructorId);
    
    if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ClassSession.fromMap(
          doc.data() as Map<String, dynamic>, 
          doc.id
        );
      }).toList();
    });
  }

  // Check for room conflicts across all instructors
  Future<Map<String, dynamic>?> checkRoomConflict({
    required String room,
    required int dayIndex,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? excludeScheduleId,
  }) async {
    final newStartMins = startHour * 60 + startMinute;
    final newEndMins = endHour * 60 + endMinute;

    // Query all schedules for the same day
    final snapshot = await _schedulesRef
        .where('dayIndex', isEqualTo: dayIndex)
        .get();

    for (var doc in snapshot.docs) {
      // Skip the schedule being edited
      if (doc.id == excludeScheduleId) continue;

      final data = doc.data() as Map<String, dynamic>;
      final existingRoom = data['subtitle'] ?? '';

      // Check if same room (case-insensitive)
      if (existingRoom.toLowerCase() == room.toLowerCase()) {
        final existingStartMins = (data['startHour'] ?? 0) * 60 + (data['startMinute'] ?? 0);
        final existingEndMins = (data['endHour'] ?? 0) * 60 + (data['endMinute'] ?? 0);

        // Check for time overlap: (StartA < EndB) && (EndA > StartB)
        if (newStartMins < existingEndMins && newEndMins > existingStartMins) {
          // Conflict found, return details
          return {
            'room': existingRoom,
            'instructorName': data['instructorName'] ?? 'Unknown',
            'instructorId': data['instructorId'] ?? '',
            'startHour': data['startHour'] ?? 0,
            'startMinute': data['startMinute'] ?? 0,
            'endHour': data['endHour'] ?? 0,
            'endMinute': data['endMinute'] ?? 0,
            'title': data['title'] ?? '',
          };
        }
      }
    }

    return null; // No conflict
  }
}
