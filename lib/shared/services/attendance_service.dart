import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'Attendance';

  /// Record attendance for a student for a SPECIFIC SCHEDULE/CLASS SESSION
  /// Returns true if successful, false if already marked present for this schedule
  Future<bool> recordAttendance({
    required String studentId,
    required String studentName,
    required String studentNumber,
    required String classId,
    String? scheduleId,
    String? scheduleTitle,
    String? instructorId,
    String? instructorName,
    String? className,
    String? sourceImagePath, // NEW
  }) async {
    try {
      final now = DateTime.now();
      final dateStr = Attendance.formatDate(now);

      // Check if already marked present for this SCHEDULE today (not just the day)
      var query = _firestore
          .collection(_collection)
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: dateStr);
      
      // If we have a scheduleId, check for that specific schedule
      if (scheduleId != null && scheduleId.isNotEmpty) {
        query = query.where('scheduleId', isEqualTo: scheduleId);
      } else {
        // Fallback to classId if no scheduleId
        query = query.where('classId', isEqualTo: classId);
      }
      
      final existing = await query.limit(1).get();

      if (existing.docs.isNotEmpty) {
        return false; // Already marked present for this schedule
      }

      // Create new attendance record
      final attendance = Attendance(
        id: '', // Will be set by Firestore
        studentId: studentId,
        studentName: studentName,
        studentNumber: studentNumber,
        classId: classId,
        scheduleId: scheduleId,
        scheduleTitle: scheduleTitle,
        instructorId: instructorId,
        instructorName: instructorName,
        className: className,
        date: dateStr,
        timestamp: now,
        isPresent: true,
        sourceImagePath: sourceImagePath,
      );

      await _firestore.collection(_collection).add(attendance.toMap());
      return true;
    } catch (e) {
      throw Exception('Failed to record attendance: $e');
    }
  }

  /// Check if student is already marked present for a specific SCHEDULE today
  Future<bool> isAlreadyMarkedPresent(String studentId, {String? scheduleId, String? classId}) async {
    try {
      final dateStr = Attendance.formatDate(DateTime.now());
      
      var query = _firestore
          .collection(_collection)
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: dateStr);
      
      if (scheduleId != null && scheduleId.isNotEmpty) {
        query = query.where('scheduleId', isEqualTo: scheduleId);
      } else if (classId != null) {
        query = query.where('classId', isEqualTo: classId);
      }
      
      final result = await query.limit(1).get();

      return result.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check attendance: $e');
    }
  }

  /// Record attendance for multiple students detected by their identity
  /// Returns map of identity -> success status
  Future<Map<String, bool>> recordAttendanceForDetectedStudents({
    required List<String> detectedIdentities,
    required String classId,
    String? scheduleId,
    String? scheduleTitle,
    String? instructorId,
    String? instructorName,
    String? className,
    String? sourceImagePath, // NEW
  }) async {
    final results = <String, bool>{};
    debugPrint('DEBUG: Starting attendance for identities: $detectedIdentities');

    for (final identity in detectedIdentities) {
      try {
        // Create variations to allow case-insensitive matching
        // e.g. "nix" -> ["nix", "NIX", "Nix"]
        final Set<String> variations = {
          identity,
          identity.toUpperCase(),
          identity.toLowerCase(),
          identity.length > 1 
              ? identity[0].toUpperCase() + identity.substring(1).toLowerCase() 
              : identity.toUpperCase()
        };

        debugPrint('DEBUG: Searching for student with identity variations: $variations');
        
        // Find student matching ANY of these variations
        final studentQuery = await _firestore
            .collection('Students')
            .where('identity', whereIn: variations.toList())
            .limit(1)
            .get();

        if (studentQuery.docs.isEmpty) {
          debugPrint('DEBUG: No student found matching any variation of "$identity"');
          debugPrint('DEBUG: Please ensuring the "identity" field in their profile matches one of: $variations');
          results[identity] = false;
          continue;
        }

        final studentDoc = studentQuery.docs.first;
        final studentData = studentDoc.data();
        final studentId = studentDoc.id;
        
        debugPrint('DEBUG: Found student: ${studentData['fullName']} (ID: $studentId)');

        // Extract student info
        final firstName = studentData['firstName'] ?? '';
        final lastName = studentData['lastName'] ?? '';
        final studentName = '$lastName, $firstName'.trim();
        final studentNumber = studentData['studentNumber'] ?? '';
        final studentClassId = studentData['classId'] ?? classId;

        // Record attendance
        debugPrint('DEBUG: Recording attendance for $studentName in schedule $scheduleId');
        final success = await recordAttendance(
          studentId: studentId,
          studentName: studentName,
          studentNumber: studentNumber,
          classId: studentClassId,
          scheduleId: scheduleId,
          scheduleTitle: scheduleTitle,
          instructorId: instructorId,
          instructorName: instructorName,
          className: className,
          sourceImagePath: sourceImagePath,
        );

        results[identity] = success;
        debugPrint('Attendance for $identity ($studentName): ${success ? "recorded" : "already present"}');
      } catch (e) {
        debugPrint('Error recording attendance for $identity: $e');
        results[identity] = false;
      }
    }

    return results;
  }

  /// Get attendance records for a specific student
  Stream<List<Attendance>> getAttendanceForStudent(String studentId) {
    return _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Attendance.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get attendance records for a specific class on a specific date
  Stream<List<Attendance>> getAttendanceForClassAndDate(
    String classId,
    String date,
  ) {
    return _firestore
        .collection(_collection)
        .where('classId', isEqualTo: classId)
        .where('date', isEqualTo: date)
        .orderBy('studentName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Attendance.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get attendance records for MULTIPLE class IDs (same class name) on a specific date
  Stream<List<Attendance>> getAttendanceForClassesAndDate(
    List<String> classIds,
    String date,
  ) {
    if (classIds.isEmpty) return Stream.value([]);

    // Firestore 'whereIn' is limited to 10 values
    final safeClassIds = classIds.take(10).toList();

    return _firestore
        .collection(_collection)
        .where('classId', whereIn: safeClassIds)
        .where('date', isEqualTo: date)
        // Note: Ordering by studentName requires a composite index with classId array
        // If that fails, we can sort client-side
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Attendance.fromMap(doc.data(), doc.id))
              .toList();
          
          // Client-side sort to be safe/consistent
          list.sort((a, b) => a.studentName.compareTo(b.studentName));
          return list;
        });
  }

  /// Get attendance records for a specific class (all dates)
  Stream<List<Attendance>> getAttendanceForClass(String classId) {
    return _firestore
        .collection(_collection)
        .where('classId', isEqualTo: classId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Attendance.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get attendance statistics for a student in a specific class
  Future<Map<String, int>> getAttendanceStats(
    String studentId,
    String classId,
  ) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('studentId', isEqualTo: studentId)
          .where('classId', isEqualTo: classId)
          .where('isPresent', isEqualTo: true)
          .get();

      final totalPresent = query.docs.length;
      
      // Get unique dates
      final uniqueDates = query.docs
          .map((doc) => doc.data()['date'] as String)
          .toSet()
          .length;

      return {
        'totalPresent': totalPresent,
        'uniqueDays': uniqueDates,
      };
    } catch (e) {
      throw Exception('Failed to get attendance stats: $e');
    }
  }

  /// Get all unique dates with attendance for a class
  Future<List<String>> getAttendanceDatesForClass(String classId) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('classId', isEqualTo: classId)
          .orderBy('date', descending: true)
          .get();

      final dates = query.docs
          .map((doc) => doc.data()['date'] as String)
          .toSet()
          .toList();

      return dates;
    } catch (e) {
      throw Exception('Failed to get attendance dates: $e');
    }
  }
  /// Get weekly attendance statistics for a specific student
  Future<Map<String, dynamic>> getStudentWeeklyAttendanceStats(String studentId, {DateTime? endDate}) async {
    try {
      final now = endDate ?? DateTime.now();
      // Calculate start of the WEEK (Monday)
      // DateTime.weekday: Mon=1, Sun=7
      final daysSinceMonday = now.weekday - 1;
      final start = now.subtract(Duration(days: daysSinceMonday));
      
      // We need to query by date string "yyyy-MM-dd"
      // Since we can't do a range query on string dates easily unless they are ISO (which they are),
      // effectively we can use >= startStr and <= endStr if the format allows.
      // Attendance.formatDate uses "yyyy-MM-dd", so string comparison works lexicographically.
      
      final startStr = Attendance.formatDate(start);
      final endStr = Attendance.formatDate(now);
      
      // Query attendance for this student within date range
      final query = await _firestore
          .collection(_collection)
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr)
          .get();
          
      final docs = query.docs;
      
      // Process data
      // 1. Initialize counts for last 7 days
      List<int> dailyCounts = List.filled(7, 0);
      List<String> dayLabels = [];
      
      // Map to store count per date string
      Map<String, int> countsByDate = {};
      
      for (int i = 0; i < 7; i++) {
        final date = start.add(Duration(days: i));
        final dateString = Attendance.formatDate(date);
        countsByDate[dateString] = 0;
        dayLabels.add(DateFormat('E').format(date)); // Mon, Tue, etc.
      }
      
      // 2. Count attendance records
      int weekCount = 0;
      int todayCount = 0;
      final todayStr = Attendance.formatDate(DateTime.now());
      
      for (var doc in docs) {
        final data = doc.data();
        final dateStr = data['date'] as String;
        
        if (countsByDate.containsKey(dateStr)) {
          countsByDate[dateStr] = (countsByDate[dateStr] ?? 0) + 1;
        }
        
        weekCount++;
        if (dateStr == todayStr) {
          todayCount++;
        }
      }
      
      // 3. Fill dailyCounts list in order
      for (int i = 0; i < 7; i++) {
        final date = start.add(Duration(days: i));
        final dateString = Attendance.formatDate(date);
        dailyCounts[i] = countsByDate[dateString] ?? 0;
      }
      
      return {
        'weeklyCounts': dailyCounts,
        'dayLabels': dayLabels,
        'todayCount': todayCount,
        'weekCount': weekCount,
      };
      
    } catch (e) {
      debugPrint('Error getting student weekly stats: $e');
      // Return empty stats on error to avoid crashing UI
      return {
        'weeklyCounts': List.filled(7, 0),
        'dayLabels': List.filled(7, ''),
        'todayCount': 0,
        'weekCount': 0,
      };
    }
  }
  /// Count unique students present today across specific classes
  Future<int> countUniqueStudentsPresentToday(List<String> classIds) async {
    try {
      if (classIds.isEmpty) return 0;
      
      final dateStr = Attendance.formatDate(DateTime.now());
      // Firestore 'whereIn' is limited to 10 values
      final safeClassIds = classIds.take(10).toList();

      final query = await _firestore
          .collection(_collection)
          .where('classId', whereIn: safeClassIds)
          .where('date', isEqualTo: dateStr)
          .get();

      final uniqueStudentIds = query.docs
          .map((doc) => doc.data()['studentId'] as String)
          .toSet();

      return uniqueStudentIds.length;
    } catch (e) {
      debugPrint('Error counting unique students: $e');
      return 0;
    }
  }

  /// Get weekly attendance statistics for specific classes (Class-Wide Unique Counts)
  /// Refactored to avoid "Index Required" error by using multiple simple Equality queries
  Future<Map<String, dynamic>> getClassWeeklyUniqueAttendanceStats(List<String> classIds, {DateTime? endDate}) async {
    try {
      if (classIds.isEmpty) {
        return {
          'weeklyCounts': List.filled(7, 0),
          'dayLabels': List.filled(7, ''),
          'todayCount': 0,
          'weekCount': 0,
        };
      }

      final now = endDate ?? DateTime.now();
      // Calculate start of the WEEK (Monday)
      final daysSinceMonday = now.weekday - 1;
      final start = now.subtract(Duration(days: daysSinceMonday));
      final safeClassIds = classIds.take(10).toList(); // Firestore whereIn limit

      // Data structures
      List<int> dailyCounts = List.filled(7, 0);
      List<String> dayLabels = [];
      Map<String, Set<String>> uniqueStudentsByDate = {};

      int weekCount = 0;
      int todayCount = 0;
      final todayStr = Attendance.formatDate(DateTime.now());

      // Create a list of futures to run in parallel
      List<Future<void>> futures = [];

      for (int i = 0; i < 7; i++) {
        final date = start.add(Duration(days: i));
        final dateString = Attendance.formatDate(date);
        dayLabels.add(DateFormat('E').format(date));
        uniqueStudentsByDate[dateString] = {};
        
        // Define the query as a closure/future
        futures.add(Future(() async {
          try {
            // Use Equality on Date + WhereIn on ClassId
            // This usually doesn't require a composite index if fields are few
            // If it still fails, it's easier to fix than a range query
            final query = await _firestore
                .collection(_collection)
                .where('classId', whereIn: safeClassIds)
                .where('date', isEqualTo: dateString) // Simple Equality
                .get();

            final docs = query.docs;
            debugPrint('SERVICE: Query for date $dateString with classIds $safeClassIds found ${docs.length} records');
            
            for (var doc in docs) {
               final studentId = doc.data()['studentId'] as String;
               uniqueStudentsByDate[dateString]!.add(studentId);
            }
          } catch (e) {
            debugPrint('Error fetching daily stats for $dateString: $e');
          }
        }));
      }

      // Execute all 7 queries in parallel
      await Future.wait(futures);
      
      // Calculate totals from results
      for (int i = 0; i < 7; i++) {
        final date = start.add(Duration(days: i));
        final dateString = Attendance.formatDate(date);
        final count = uniqueStudentsByDate[dateString]?.length ?? 0;
        
        dailyCounts[i] = count;
        weekCount += count;
        
        if (dateString == todayStr) {
          todayCount = count;
        }
      }
      
      return {
        'weeklyCounts': dailyCounts,
        'dayLabels': dayLabels,
        'todayCount': todayCount,
        'weekCount': weekCount,
      };
      
    } catch (e) {
      debugPrint('Error getting class weekly stats: $e');
      return {
        'weeklyCounts': List.filled(7, 0),
        'dayLabels': List.filled(7, ''),
        'todayCount': 0,
        'weekCount': 0,
      };
    }
  }
  /// Delete attendance records associated with a specific source image
  Future<void> deleteAttendanceBySourceImage(String imagePath) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('sourceImagePath', isEqualTo: imagePath)
          .get();

      if (query.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('Deleted ${query.docs.length} attendance records for image: $imagePath');
    } catch (e) {
      debugPrint('Error deleting attendance by image: $e');
      throw e;
    }
  }
  /// Get all attendance records for a specific class on a specific date
  Future<List<Attendance>> getAttendanceForClassDate(String classId, DateTime date) async {
    try {
      final dateStr = Attendance.formatDate(date);
      debugPrint('SERVICE: Fetching attendance for class $classId on $dateStr');

      final query = await _firestore
          .collection(_collection)
          .where('classId', isEqualTo: classId)
          .where('date', isEqualTo: dateStr)
          .get();

      return query.docs
          .map((doc) => Attendance.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching class date attendance: $e');
      return [];
    }
  }
}
