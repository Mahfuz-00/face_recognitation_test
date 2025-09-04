class Student {
  final int id;
  final String name;
  final String rollNo;
  final List<double> faceEmbedding;

  Student({required this.id, required this.name, required this.rollNo, required this.faceEmbedding});

  factory Student.fromJson(Map<String, dynamic> j) {
    final List<dynamic> emb = j['face_embedding'] ?? [];
    return Student(
      id: j['id'] is int ? j['id'] : int.parse(j['id'].toString()),
      name: j['name'] ?? '',
      rollNo: j['roll_no'] ?? '',
      faceEmbedding: emb.map((e) => (e as num).toDouble()).toList(),
    );
  }
}