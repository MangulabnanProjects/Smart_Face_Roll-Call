import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String id;
  final String studentId;
  final String studentName;
  final String studentNumber; // NEW: Student number
  final String classId;
  final String? scheduleId; // NEW: Specific schedule/session ID
  final String? scheduleTitle; // NEW: Subject name (e.g., "Python 203")
  final String? instructorId; // NEW: Instructor ID
  final String? instructorName; // NEW: Instructor name
  final String? className; // NEW: Class group name (e.g., "BSCS-4A")
  final String date; // YYYY-MM-DD format
  final DateTime timestamp;
  final bool isPresent;
  final String? sourceImagePath; // NEW: Link to source image


  Attendance({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentNumber,
    required this.classId,
    this.scheduleId,
    this.scheduleTitle,
    this.instructorId,
    this.instructorName,
    this.className,
    required this.date,
    required this.timestamp,
    required this.isPresent,
    this.sourceImagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentNumber': studentNumber,
      'classId': classId,
      'scheduleId': scheduleId,
      'scheduleTitle': scheduleTitle,
      'instructorId': instructorId,
      'instructorName': instructorName,
      'className': className,
      'date': date,
      'timestamp': Timestamp.fromDate(timestamp),
      'isPresent': isPresent,
      'sourceImagePath': sourceImagePath,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map, String docId) {
    return Attendance(
      id: docId,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentNumber: map['studentNumber'] ?? '',
      classId: map['classId'] ?? '',
      scheduleId: map['scheduleId'],
      scheduleTitle: map['scheduleTitle'],
      instructorId: map['instructorId'],
      instructorName: map['instructorName'],
      className: map['className'],
      date: map['date'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPresent: map['isPresent'] ?? false,
      sourceImagePath: map['sourceImagePath'],
    );
  }

  // Helper to create date string in YYYY-MM-DD format
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
