class Student {
  final int id;
  final String name;
  final String rollNo;
  final int classId;
  final List<double> faceEmbedding;

  Student({required this.id, required this.name, required this.rollNo, required this.classId, required this.faceEmbedding});

  factory Student.fromJson(Map<String, dynamic> j) {
    final List<dynamic> emb = j['face_embedding'] ?? [];
    return Student(
      id: j['id'] is int ? j['id'] : int.parse(j['id'].toString()),
      name: j['name'] ?? '',
      rollNo: j['roll_no'] ?? '',
      classId: j['class_id'] as int,
      faceEmbedding: emb.map((e) => (e as num).toDouble()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roll_no': rollNo,
      'class_id': classId,
      'face_embedding': faceEmbedding,
    };
  }

}