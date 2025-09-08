import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../Models/students.dart';

class ApiService {
  // File to store student data locally
  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/students.json');
  }

  // Initialize the file if it doesn't exist
  Future<void> _initializeFile() async {
    final file = await _getLocalFile();
    if (!await file.exists()) {
      await file.writeAsString(jsonEncode({'students': [], 'attendance': []}));
    }
  }

  Future<bool> registerStudent({
    required String name,
    required String rollNo,
    required int classId,
    required List<double> embedding,
  }) async {
    try {
      await _initializeFile();
      final file = await _getLocalFile();
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Generate a unique student ID (e.g., based on existing students)
      final students = (jsonData['students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final newId = students.isEmpty ? 1 : (students.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1);

      final newStudent = {
        'id': newId,
        'name': name,
        'roll_no': rollNo,
        'class_id': classId,
        'face_embedding': embedding,
      };

      students.add(newStudent);
      jsonData['students'] = students;

      await file.writeAsString(jsonEncode(jsonData));
      return true; // Equivalent to HTTP 200/201
    } catch (e) {
      print('Error registering student: $e');
      return false;
    }
  }

  Future<List<Student>?> fetchClassStudents(int classId) async {
    try {
      await _initializeFile();
      final file = await _getLocalFile();
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      final students = (jsonData['students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final filteredStudents = students.where((e) => e['class_id'] == classId).map((e) => Student.fromJson(e)).toList();
      return filteredStudents;
    } catch (e) {
      print('Error fetching students: $e');
      return null;
    }
  }

  Future<bool> postAttendance({
    required int classId,
    required int studentId,
  }) async {
    try {
      await _initializeFile();
      final file = await _getLocalFile();
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      final attendance = (jsonData['attendance'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      attendance.add({
        'class_id': classId,
        'student_id': studentId,
        'taken_at': DateTime.now().toIso8601String(),
      });

      jsonData['attendance'] = attendance;
      await file.writeAsString(jsonEncode(jsonData));
      return true; // Equivalent to HTTP 200/201
    } catch (e) {
      print('Error posting attendance: $e');
      return false;
    }
  }
}