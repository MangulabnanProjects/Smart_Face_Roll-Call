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
  // Modified to match by class NAME so students appear for all instructors teaching the same class
  Stream<List<Student>> getStudentsByClass(String classId) async* {
    // First, get the class name for this classId
    final classDoc = await FirebaseFirestore.instance
        .collection('ClassGroups')
        .doc(classId)
        .get();
    
    if (!classDoc.exists) {
      yield [];
      return;
    }
    
    final className = (classDoc.data() as Map<String, dynamic>)['name'] as String? ?? '';
    
    if (className.isEmpty) {
      yield [];
      return;
    }
    
    // Get all class groups with the same name
    final classGroupsSnapshot = await FirebaseFirestore.instance
        .collection('ClassGroups')
        .where('name', isEqualTo: className)
        .get();
    
    final classIds = classGroupsSnapshot.docs.map((doc) => doc.id).toList();
    
    if (classIds.isEmpty) {
      yield [];
      return;
    }
    
    // Now stream students who have any of these classIds
    await for (var snapshot in _studentCollection.snapshots()) {
      final students = snapshot.docs
          .map((doc) {
            return Student.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          })
          .where((student) => classIds.contains(student.classId))
          .toList();
      
      // Sort client-side by fullName
      students.sort((a, b) => a.fullName.compareTo(b.fullName));
      yield students;
    }
  }

  // Delete a student
  Future<void> deleteStudent(String studentId) async {
    await _studentCollection.doc(studentId).delete();
  }
}
