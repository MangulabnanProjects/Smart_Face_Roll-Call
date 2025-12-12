import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_group.dart';

class ClassService {
  final CollectionReference _classCollection = FirebaseFirestore.instance.collection('ClassGroups');
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Add a new class group
  Future<void> addClassGroup(String name) async {
    if (_currentUser == null) throw Exception('User not logged in');
    
    await _classCollection.add({
      'name': name,
      'instructorId': _currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get stream of class groups for current instructor
  // Note: Filtering client-side to avoid Firestore index requirement
  Stream<List<ClassGroup>> getClassGroupsStream() {
    if (_currentUser == null) return Stream.value([]);

    return _classCollection
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
          .map((doc) => ClassGroup.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((group) => group.instructorId == _currentUser!.uid)
          .toList();
      });
  }

  // Delete a class group
  Future<void> deleteClassGroup(String classId) async {
    await _classCollection.doc(classId).delete();
    // Note: Ideally, we should also delete all schedules associated with this classId
  }
}
