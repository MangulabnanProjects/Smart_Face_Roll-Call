import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String studentNumber;
  final String fullName;
  final DateTime birthday;
  final String email;
  final String phoneNumber;
  final String classId;

  Student({
    required this.id,
    required this.studentNumber,
    required this.fullName,
    required this.birthday,
    required this.email,
    required this.phoneNumber,
    required this.classId,
  });

  String get firstName => fullName.split(' ').first;
  String get lastName => fullName.split(' ').length > 1 ? fullName.split(' ').sublist(1).join(' ') : '';

  Map<String, dynamic> toMap() {
    return {
      'studentNumber': studentNumber,
      'fullName': fullName,
      'birthday': Timestamp.fromDate(birthday),
      'email': email,
      'phoneNumber': phoneNumber,
      'classId': classId,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map, String docId) {
    return Student(
      id: docId,
      studentNumber: map['studentNumber'] ?? '',
      fullName: map['fullName'] ?? '',
      birthday: (map['birthday'] as Timestamp?)?.toDate() ?? DateTime.now(),
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      classId: map['classId'] ?? '',
    );
  }
}
