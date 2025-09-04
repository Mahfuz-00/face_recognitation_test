import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../Services/face_service.dart';
import '../../Services/api_service.dart';
import '../../Models/students.dart';

class FaceHome extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FaceHome({super.key, required this.cameras});

  @override
  State<FaceHome> createState() => _FaceHomeState();
}

class _FaceHomeState extends State<FaceHome> {
  late CameraController _controller;
  bool _cameraReady = false;
  final _faceService = FaceService();
  final _api = ApiService();

  final int classId = 101; // set as needed

  @override
  void initState() {
    super.initState();
    debugPrint("Initializing camera...");
    _initCamera();
  }

  Future<void> _initCamera() async {
    final camera = widget.cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );
    _controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);

    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
      debugPrint("Camera initialized successfully: ${camera.name}");
    } catch (e) {
      debugPrint("Camera initialization failed: $e");
    }
  }

  @override
  void dispose() {
    debugPrint("Disposing camera and face service...");
    _controller.dispose();
    _faceService.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureJpegBytes() async {
    try {
      final shot = await _controller.takePicture();
      final bytes = await shot.readAsBytes();
      debugPrint("Captured image of size: ${bytes.lengthInBytes} bytes");
      return bytes;
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  Future<void> _registerStudentDialog() async {
    final nameCtrl = TextEditingController();
    final rollCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: rollCtrl, decoration: const InputDecoration(labelText: 'Roll No')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              debugPrint("Registering student: ${nameCtrl.text}, Roll: ${rollCtrl.text}");
              await _registerStudent(nameCtrl.text.trim(), rollCtrl.text.trim());
            },
            child: const Text('Capture & Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerStudent(String name, String rollNo) async {
    if (name.isEmpty || rollNo.isEmpty) {
      _snack('Name & Roll required');
      debugPrint("Registration failed: empty name or roll");
      return;
    }

    final bytes = await _captureJpegBytes();
    if (bytes == null) {
      _snack('Failed to capture image.');
      debugPrint("Registration failed: capture returned null");
      return;
    }

    _snack('Processing face...');
    debugPrint("Processing face for student registration...");
    final embedding = await _faceService.processFace(bytes);
    if (embedding == null) {
      _snack('Failed to process face.');
      debugPrint("Face embedding returned null");
      return;
    }

    debugPrint("Face embedding generated successfully, registering via API...");
    final success = await _api.registerStudent(
      name: name,
      rollNo: rollNo,
      classId: classId,
      embedding: embedding,
    );

    if (success) {
      _snack('Student registered');
      debugPrint("Student registered successfully: $name");
    } else {
      _snack('Register failed');
      debugPrint("API registration failed for $name");
    }
  }

  Future<void> _takeAttendance() async {
    final bytes = await _captureJpegBytes();
    if (bytes == null) {
      _snack('Failed to capture image.');
      debugPrint("Attendance capture failed");
      return;
    }

    _snack('Processing face...');
    debugPrint("Processing face for attendance...");
    final capturedEmbedding = await _faceService.processFace(bytes);
    if (capturedEmbedding == null) {
      _snack('Failed to process face.');
      debugPrint("Face embedding for attendance returned null");
      return;
    }

    _snack('Fetching class list...');
    debugPrint("Fetching students for classId $classId...");
    final students = await _api.fetchClassStudents(classId);
    if (students == null || students.isEmpty) {
      _snack('No students found');
      debugPrint("No students returned from API");
      return;
    }

    double bestSim = -2.0;
    Student? bestMatch;

    for (final s in students) {
      final sim = FaceService.cosineSimilarity(capturedEmbedding, s.faceEmbedding);
      debugPrint("Similarity with ${s.name}: $sim");
      if (sim > bestSim) {
        bestSim = sim;
        bestMatch = s;
      }
    }

    const double THRESHOLD = 0.80;
    if (bestMatch != null && bestSim >= THRESHOLD) {
      _snack('Matched: ${bestMatch.name} (sim=${bestSim.toStringAsFixed(3)})');
      debugPrint("Attendance recorded for ${bestMatch.name}");
      await _api.postAttendance(classId: classId, studentId: bestMatch.id);
    } else {
      _snack('No match (best=${bestSim.toStringAsFixed(3)})');
      debugPrint("No matching student found. Best similarity: $bestSim");
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Attendance')),
      body: !_cameraReady
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          CameraPreview(_controller),
          Center(
            child: Container(
              width: 260,
              height: 320,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(160),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton.tonal(
                  onPressed: _registerStudentDialog,
                  child: const Text('Register'),
                ),
                FilledButton(
                  onPressed: _takeAttendance,
                  child: const Text('Take Attendance'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
