import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/class_session.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'Schedules';

  /// Get current active schedule for a class
  /// Returns schedule info if currently in class time, null otherwise
  Future<Map<String, String?>> getCurrentScheduleForClass(String classId) async {
    try {
      final now = DateTime.now();
      final currentDay = now.weekday - 1; // Mon=0
      final currentMinutes = now.hour * 60 + now.minute;

      final scheduleQuery = await _firestore
          .collection(_collection)
          .where('classId', isEqualTo: classId)
          .where('dayIndex', isEqualTo: currentDay)
          .get();

      for (var doc in scheduleQuery.docs) {
        final data = doc.data();
        final startHour = data['startHour'] as int? ?? 0;
        final startMinute = data['startMinute'] as int? ?? 0;
        final endHour = data['endHour'] as int? ?? 0;
        final endMinute = data['endMinute'] as int? ?? 0;

        final startMinutes = startHour * 60 + startMinute;
        final endMinutes = endHour * 60 + endMinute;

        if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
          return {
            'scheduleId': doc.id,
            'scheduleTitle': data['title'] as String? ?? '',
            'instructorId': data['instructorId'] as String? ?? '',
            'instructorName': data['instructorName'] as String? ?? '',
            'className': data['className'] as String?,
            'classId': data['classId'] as String? ?? '',
          };
        }
      }

      return {
        'scheduleId': null,
        'scheduleTitle': null,
        'instructorId': null,
        'instructorName': null,
        'className': null,
        'classId': null,
      };
    } catch (e) {
      debugPrint('Error getting current schedule: $e');
      return {
        'scheduleId': null,
        'scheduleTitle': null,
        'instructorId': null,
        'instructorName': null,
        'className': null,
        'classId': null,
      };
    }
  }

  /// Check if camera/import is currently allowed for a class
  Future<bool> isCameraAllowedForClass(String classId) async {
    final schedule = await getCurrentScheduleForClass(classId);
    return schedule['scheduleId'] != null;
  }

  /// Get restriction message with next class time
  Future<String> getRestrictionMessageForClass(String classId) async {
    if (await isCameraAllowedForClass(classId)) {
      return "";
    }

    // Get next schedule
    final now = DateTime.now();
    final schedules = await getSchedulesForClass(classId);

    if (schedules.isEmpty) {
      return "No class schedule found. Please contact your instructor.";
    }

    // Find next upcoming class
    ClassSession? nextClass;
    int? daysUntil;

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final checkDate = now.add(Duration(days: dayOffset));
      final dayIndex = checkDate.weekday - 1;

      for (final schedule in schedules) {
        if (schedule.dayIndex == dayIndex) {
          final classStart = DateTime(
            checkDate.year,
            checkDate.month,
            checkDate.day,
            schedule.startTime.hour,
            schedule.startTime.minute,
          );

          if (classStart.isAfter(now)) {
            nextClass = schedule;
            daysUntil = dayOffset;
            break;
          }
        }
      }
      if (nextClass != null) break;
    }

    if (nextClass == null) {
      return "Camera only available during class hours.";
    }

    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = days[nextClass.dayIndex];
    final timeStr = '${nextClass.startTime.hour.toString().padLeft(2, '0')}:${nextClass.startTime.minute.toString().padLeft(2, '0')}';

    if (daysUntil == 0) {
      return "Camera available today at $timeStr";
    } else if (daysUntil == 1) {
      return "Camera available tomorrow ($dayName) at $timeStr";
    } else {
      return "Camera available on $dayName at $timeStr";
    }
  }

  /// Get all schedules for a class
  Future<List<ClassSession>> getSchedulesForClass(String classId) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('classId', isEqualTo: classId)
          .get();

      return query.docs
          .map((doc) => ClassSession.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching class schedules: $e');
      return [];
    }
  }

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
  Future<Map<String, dynamic>?> checkRoomConflict({
    required String room,
    required int dayIndex,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? excludeScheduleId,
  }) async {
    final query = await _firestore
        .collection(_collection)
        .where('subtitle', isEqualTo: room)
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

  /// 6. Check for Class Conflicts
  Future<Map<String, dynamic>?> checkClassConflict({
    required String classId,
    required int dayIndex,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String? excludeScheduleId,
  }) async {
    if (classId.isEmpty) return null;

    final query = await _firestore
        .collection(_collection)
        .where('classId', isEqualTo: classId)
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

      if (newStartMins < existingEndTotal && newEndMins > existingStartTotal) {
         return {
           'classId': classId,
           'instructorName': data['instructorName'],
           'room': data['subtitle'],
           'title': data['title'],
           'startHour': existingStartHour,
           'startMinute': existingStartMin,
           'endHour': existingEndHour,
           'endMinute': existingEndMin,
         };
      }
    }
    return null;
  }

  /// 7. Get Schedules for a Class on a Specific Date
  Future<List<ClassSession>> getSchedulesForClassDate(String classId, DateTime date) async {
    try {
      final dayIndex = date.weekday - 1;

      final query = await _firestore
          .collection(_collection)
          .where('classId', isEqualTo: classId)
          .where('dayIndex', isEqualTo: dayIndex)
          .get();

      return query.docs
          .map((doc) => ClassSession.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching class schedules: $e');
      return [];
    }
  }
}
