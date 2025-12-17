import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/class_session.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'Schedules';

  /// 1. Get Stream of schedules for a specific instructor
  Stream<List<ClassSession>> getSchedulesStream(String instructorId) {
    return _firestore
        .collection(_collection)
        .where('instructorId', isEqualTo: instructorId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ClassSession.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// 2. Add a new schedule
  Future<void> addSchedule(ClassSession session) async {
    await _firestore.collection(_collection).add(session.toMap());
  }

  /// 3. Update an existing schedule
  Future<void> updateSchedule(ClassSession session) async {
    await _firestore.collection(_collection).doc(session.id).update(session.toMap());
  }

  /// 4. Delete a schedule
  Future<void> deleteSchedule(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// 5. Check for Room Conflicts
  /// Returns null if no conflict, or a Map/Object with conflict details if one exists
  Future<Map<String, dynamic>?> checkRoomConflict({
    required String room,
    required int dayIndex,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? excludeScheduleId,
  }) async {
    // We have to query broadly because Firestore filtering on multiple inequality fields is limited.
    // Query schedules for that Room and Day
    final query = await _firestore
        .collection(_collection)
        .where('subtitle', isEqualTo: room) // 'subtitle' stores the Room Number
        .where('dayIndex', isEqualTo: dayIndex)
        .get();

    final newStartMins = startHour * 60 + startMinute;
    final newEndMins = endHour * 60 + endMinute;

    for (var doc in query.docs) {
      if (doc.id == excludeScheduleId) continue;
      
      final data = doc.data();
      final existingStartHour = data['startHour'] as int;
      final existingStartMin = data['startMinute'] as int;
      final existingEndHour = data['endHour'] as int;
      final existingEndMin = data['endMinute'] as int;

      final existingStartTotal = existingStartHour * 60 + existingStartMin;
      final existingEndTotal = existingEndHour * 60 + existingEndMin;

      // Overlap logic: (StartA < EndB) and (EndA > StartB)
      if (newStartMins < existingEndTotal && newEndMins > existingStartTotal) {
         return {
           'room': room,
           'instructorName': data['instructorName'],
           'startHour': existingStartHour,
           'startMinute': existingStartMin,
           'endHour': existingEndHour,
           'endMinute': existingEndMin,
         };
      }
    }
    return null;
  }

  // --- STUDENT CAMERA RESTRICTION LOGIC (Mock/Placeholder) ---
  
  // Mock Schedule Data (Temporary)
  static final Map<String, List<Map<String, dynamic>>> _mockSchedules = {
    'BSCS-4A': [
      {'day': 1, 'start': '14:00', 'end': '17:00'}, // Monday 2PM - 5PM
      {'day': 3, 'start': '14:00', 'end': '17:00'}, // Wednesday 2PM - 5PM
    ],
    'BSCS-3B': [
      {'day': 2, 'start': '08:00', 'end': '11:00'}, // Tuesday 8AM - 11AM
    ],
  };

  /// Checks if the current time matches the student's class schedule
  /// This is currently static as requested, separate from the Firestore logic
  static bool isCameraAllowed(String section) {
    // 1. Get current time
    final now = DateTime.now();
    final currentDay = now.weekday - 1; // Dart Mon=1..7, but App uses Mon=0..6 match check!
    // WAIT: _days in manage_screen is 0-based index [Mon, Tue...]. 
    // Dart DateTime.weekday is Mon=1, Sun=7.
    // So for Mon(1), index is 0.
    final dayIndex = now.weekday - 1; 
    
    // 2. Get schedule for the section
    final schedules = _mockSchedules[section];
    if (schedules == null) {
      return true; // Default to allow if no schedule defined
    }

    // 3. Check if today is a class day
    for (final classTime in schedules) {
      // Mock data uses 1=Mon? Let's assume Mock Data follows Dart standard (1=Mon) to be safe or adjust.
      // Let's standardize: Mock data keys 'day' are 1=Mon.
      if (classTime['day'] == now.weekday) {
        // 4. Check time window
        final startTime = _parseTime(classTime['start'], now);
        final endTime = _parseTime(classTime['end'], now);

        if (now.isAfter(startTime) && now.isBefore(endTime)) {
          return true; // Within class hours
        }
      }
    }

    return false;
  }

  static DateTime _parseTime(String timeStr, DateTime now) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static String getRestrictionMessage(String section) {
    if (isCameraAllowed(section)) return "";
    return "Attendance is only allowed during your scheduled class hours.";
  }
}
