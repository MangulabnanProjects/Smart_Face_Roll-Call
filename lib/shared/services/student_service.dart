import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';

class StudentService {
  final CollectionReference _studentCollection = FirebaseFirestore.instance.collection('Students');

  // Add a new student (with duplicate check)
  Future<void> addStudent(Student student) async {
    // Check if student number already exists in this class
    final query = await _studentCollection
        .where('classId', isEqualTo: student.classId)
        .where('studentNumber', isEqualTo: student.studentNumber)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      // Already exists, ignore
      return;
    }

    await _studentCollection.add(student.toMap());
  }

  // Get students by class ID as a stream
  // Note: Sorting client-side to avoid Firestore index requirement
  Stream<List<Student>> getStudentsByClass(String classId) {
    return _studentCollection
      .where('classId', isEqualTo: classId)
      .snapshots()
      .map((snapshot) {
        final students = snapshot.docs.map((doc) {
          return Student.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        // Sort client-side by fullName
        students.sort((a, b) => a.fullName.compareTo(b.fullName));
        return students;
      });
  }

  // Delete a student
  Future<void> deleteStudent(String studentId) async {
    await _studentCollection.doc(studentId).delete();
  }
}
