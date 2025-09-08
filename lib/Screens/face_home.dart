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
  bool _isProcessing = false;
  bool _isFaceProper = false;
  final _faceService = FaceService();
  final _api = ApiService();
  final int classId = 101;
  final ValueNotifier<bool> _isProcessingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isFaceProperNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    debugPrint("Initializing camera...");
    _initCamera();
    _loadModel();
    _startFaceSizeCheck();
  }

  Future<void> _loadModel() async {
    await _faceService.loadModel(context);
  }

  Future<void> _initCamera() async {
    final camera = widget.cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );
    _controller = CameraController(
      camera,
      ResolutionPreset.high, // Changed to high for sharper images
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller.initialize();
      await _controller.setFocusMode(FocusMode.auto);
      await _controller.setFocusPoint(const Offset(0.5, 0.5));
      await _controller.setExposureMode(ExposureMode.auto); // Added for lighting
      if (!mounted) return;
      setState(() => _cameraReady = true);
      debugPrint("Camera initialized: ${camera.name}, lensDirection: ${camera.lensDirection}, resolution: ${_controller.value.previewSize}");
    } catch (e) {
      debugPrint("Camera initialization failed: $e");
    }
  }

  Future<void> _startFaceSizeCheck() async {
    while (mounted) {
      if (!_isProcessing && _cameraReady) {
        final bytes = await _captureJpegBytes(silent: true);
        if (bytes != null) {
          final isProper = await _faceService.isFaceProperlySized(bytes);
          if (mounted) {
            setState(() => _isFaceProper = isProper);
            _isFaceProperNotifier.value = isProper;
          }
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<Uint8List?> _captureJpegBytes({bool silent = false}) async {
    try {
      await _controller.setFocusPoint(const Offset(0.5, 0.5));
      await _controller.setFocusMode(FocusMode.locked);
      final shot = await _controller.takePicture();
      final bytes = await shot.readAsBytes();
      await _controller.setFocusMode(FocusMode.auto);
      if (!silent) {
        debugPrint("Captured image of size: ${bytes.lengthInBytes} bytes");
      }
      return bytes;
    } catch (e) {
      if (!silent) {
        debugPrint('Capture error: $e');
      }
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
    if (_isProcessing) {
      _snack('Processing in progress, please wait...');
      debugPrint("Registration skipped: already processing");
      return;
    }
    if (!_isFaceProper) {
      _snack('Please adjust face position (30-50 cm, centered)');
      debugPrint("Registration skipped: improper face size");
      return;
    }
    _isProcessing = true;
    _isProcessingNotifier.value = true;

    try {
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
    } catch (e) {
      _snack('Error: $e');
      debugPrint("Error in _registerStudent: $e");
    } finally {
      _isProcessing = false;
      _isProcessingNotifier.value = false;
    }
  }

  Future<void> _takeAttendance() async {
    if (_isProcessing) {
      _snack('Processing in progress, please wait...');
      debugPrint("Attendance skipped: already processing");
      return;
    }
    if (!_isFaceProper) {
      _snack('Please adjust face position (30-50 cm, centered)');
      debugPrint("Attendance skipped: improper face size");
      return;
    }
    _isProcessing = true;
    _isProcessingNotifier.value = true;

    try {
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
      if (students == null) {
        _snack('Error fetching students');
        debugPrint("Failed to fetch students: returned null");
        return;
      }
      if (students.isEmpty) {
        _snack('No students found');
        debugPrint("No students found for classId $classId");
        return;
      }

      double bestSim = -2.0;
      Student? bestMatch;

      for (final s in students) {
        if (s.faceEmbedding.length != capturedEmbedding.length) {
          debugPrint("Embedding length mismatch for ${s.name}: expected ${capturedEmbedding.length}, got ${s.faceEmbedding.length}");
          continue;
        }
        final sim = FaceService.cosineSimilarity(capturedEmbedding, s.faceEmbedding);
        debugPrint("Similarity with ${s.name}: $sim");
        if (sim > bestSim) {
          bestSim = sim;
          bestMatch = s;
        }
      }

      const double THRESHOLD = 0.80;
      if (bestMatch != null) {
        if (bestSim >= THRESHOLD) {
          _snack('Matched: ${bestMatch.name} (sim=${bestSim.toStringAsFixed(3)})');
          debugPrint("Attendance recorded for ${bestMatch.name}");
          final success = await _api.postAttendance(classId: classId, studentId: bestMatch.id);
          if (success) {
            _snack('Attendance recorded for ${bestMatch.name}');
            debugPrint("Attendance successfully recorded for ${bestMatch.name}");
          } else {
            _snack('Failed to record attendance');
            debugPrint("Failed to record attendance for ${bestMatch.name}");
          }
        } else {
          _snack('Best match: ${bestMatch.name} (sim=${bestSim.toStringAsFixed(3)})');
          debugPrint("Recording attendance for best match ${bestMatch.name} (sim=$bestSim)");
          final success = await _api.postAttendance(classId: classId, studentId: bestMatch.id);
          if (success) {
            _snack('Attendance recorded for ${bestMatch.name}');
            debugPrint("Attendance successfully recorded for ${bestMatch.name}");
          } else {
            _snack('Failed to record attendance');
            debugPrint("Failed to record attendance for ${bestMatch.name}");
          }
        }
      } else {
        _snack('No match (best=${bestSim.toStringAsFixed(3)})');
        debugPrint("No matching student found. Best similarity: $bestSim");
      }
    } catch (e) {
      _snack('Error: $e');
      debugPrint("Error in _takeAttendance: $e");
    } finally {
      _isProcessing = false;
      _isProcessingNotifier.value = false;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Face Attendance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !_cameraReady
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<bool>(
        valueListenable: _isProcessingNotifier,
        builder: (context, isProcessing, child) => ValueListenableBuilder<bool>(
          valueListenable: _isFaceProperNotifier,
          builder: (context, isFaceProper, child) => Stack(
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width * _controller.value.aspectRatio,
                    child: CameraPreview(_controller),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 260,
                  height: 320,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isFaceProper ? Colors.green : Colors.red,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(160),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 400),
                  child: Text(
                    isFaceProper
                        ? 'Face position OK'
                        : 'Adjust face to 30-50 cm, center in frame',
                    style: TextStyle(
                      color: isFaceProper ? Colors.green : Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (isProcessing)
                const Center(child: CircularProgressIndicator()),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FilledButton.tonal(
                          onPressed: isProcessing || !isFaceProper
                              ? null
                              : _registerStudentDialog,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(120, 48),
                          ),
                          child: const Text('Register'),
                        ),
                        FilledButton(
                          onPressed: isProcessing || !isFaceProper
                              ? null
                              : _takeAttendance,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(120, 48),
                          ),
                          child: const Text('Take Attendance'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}