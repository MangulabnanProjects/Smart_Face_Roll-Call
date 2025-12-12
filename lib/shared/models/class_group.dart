class ClassGroup {
  final String id;
  final String name;
  final String instructorId;

  ClassGroup({
    required this.id,
    required this.name,
    required this.instructorId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'instructorId': instructorId,
    };
  }

  factory ClassGroup.fromMap(Map<String, dynamic> map, String docId) {
    return ClassGroup(
      id: docId,
      name: map['name'] ?? '',
      instructorId: map['instructorId'] ?? '',
    );
  }
}
