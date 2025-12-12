import 'package:flutter/material.dart';

class ClassSession {
  final String id;
  final String title;
  final String subtitle; // Room
  final int dayIndex; // 0=Mon, 6=Sun
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final String instructorId;
  final String instructorName;
  final String classId; // Linked to ClassGroup

  ClassSession({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.instructorId,
    required this.instructorName,
    required this.classId,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'dayIndex': dayIndex,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'color': color.value, // Save as int
      'instructorId': instructorId,
      'instructorName': instructorName,
      'classId': classId,
    };
  }

  // Create from Map (Firestore)
  factory ClassSession.fromMap(Map<String, dynamic> map, String docId) {
    return ClassSession(
      id: docId,
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      dayIndex: map['dayIndex'] ?? 0,
      startTime: TimeOfDay(
        hour: map['startHour'] ?? 9, 
        minute: map['startMinute'] ?? 0
      ),
      endTime: TimeOfDay(
        hour: map['endHour'] ?? 10, 
        minute: map['endMinute'] ?? 0
      ),
      color: Color(map['color'] ?? 0xFFBBDEFB),
      instructorId: map['instructorId'] ?? '',
      instructorName: map['instructorName'] ?? 'Unknown',
      classId: map['classId'] ?? 'default',
    );
  }
}
