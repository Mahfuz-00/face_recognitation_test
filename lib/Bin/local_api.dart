import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart' as shelf;

class Student {
  int id;
  String name;
  String rollNo;
  int classId;
  List<double> faceEmbedding;

  Student({required this.id, required this.name, required this.rollNo, required this.classId, required this.faceEmbedding});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'roll_no': rollNo,
    'class_id': classId,
    'face_embedding': faceEmbedding,
  };

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'],
      rollNo: json['roll_no'],
      classId: json['class_id'],
      faceEmbedding: List<double>.from(json['face_embedding']),
    );
  }
}

// In-memory data
final List<Student> students = [];
int studentIdCounter = 1;
final List<Map<String, dynamic>> attendance = [];

void main() async {
  final router = Router();

  // Register student
  router.post('/api/students', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    final student = Student(
      id: studentIdCounter++,
      name: payload['name'],
      rollNo: payload['roll_no'],
      classId: payload['class_id'],
      faceEmbedding: List<double>.from(payload['face_embedding']),
    );
    students.add(student);
    return Response(201, body: jsonEncode(student.toJson()), headers: {'Content-Type': 'application/json'});
  });

  // Get students by class
  router.get('/api/classes/<classId>/students', (Request req, String classId) {
    final clsId = int.tryParse(classId);
    if (clsId == null) return Response(400, body: 'Invalid classId');
    final clsStudents = students.where((s) => s.classId == clsId).toList();
    return Response.ok(jsonEncode(clsStudents.map((s) => s.toJson()).toList()), headers: {'Content-Type': 'application/json'});
  });

  // Post attendance
  router.post('/api/attendance', (Request req) async {
    final payload = jsonDecode(await req.readAsString());
    attendance.add({
      'class_id': payload['class_id'],
      'student_id': payload['student_id'],
      'taken_at': payload['taken_at'],
    });
    return Response(201, body: jsonEncode({'status': 'ok'}), headers: {'Content-Type': 'application/json'});
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router);

  final server = await serve(handler, InternetAddress.loopbackIPv4, 8080);
  print('Local API running on http://${server.address.host}:${server.port}');
}
