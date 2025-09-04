import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/students.dart';

class ApiService {
  // TODO: change to your backend
  static const String _base = 'https://your-backend.example.com';

  Future<bool> registerStudent({required String name, required String rollNo, required int classId, required List<double> embedding}) async {
    final payload = {
      'name': name,
      'roll_no': rollNo,
      'class_id': classId,
      'face_embedding': embedding,
    };
    final res = await http.post(Uri.parse('$_base/api/students'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<List<Student>?> fetchClassStudents(int classId) async {
    final res = await http.get(Uri.parse('$_base/api/classes/$classId/students'));
    if (res.statusCode != 200) return null;
    final List<dynamic> arr = jsonDecode(res.body);
    return arr.map((e) => Student.fromJson(e)).toList();
  }

  Future<bool> postAttendance({required int classId, required int studentId}) async {
    final payload = {'class_id': classId, 'student_id': studentId, 'taken_at': DateTime.now().toIso8601String()};
    final res = await http.post(Uri.parse('$_base/api/attendance'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
    return res.statusCode == 200 || res.statusCode == 201;
  }
}