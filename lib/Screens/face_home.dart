import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../Services/face_service.dart';
import '../Services/api_service.dart';
import '../Models/students.dart';
import '../Widgets/action_buttons_widget.dart';
import '../Widgets/camera_preview_widget.dart';
import '../Widgets/register_dialog_widget.dart';

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
  bool _runFaceSizeCheck = true;
  bool _showSingleButton = false;
  String? _pendingName;
  String? _pendingRollNo;
  Uint8List? _pendingImageBytes;
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
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller.initialize();
      await _controller.setFocusMode(FocusMode.auto);
      await _controller.setFocusPoint(const Offset(0.5, 0.5));
      await _controller.setExposureMode(ExposureMode.auto);
      await _controller.setExposureOffset(0.2);
      if (!mounted) return;
      setState(() => _cameraReady = true);
      debugPrint("Camera initialized: ${camera.name}, lensDirection: ${camera.lensDirection}, resolution: ${_controller.value.previewSize}");
      debugPrint("Camera details: ${_controller.description}");
    } catch (e) {
      debugPrint("Camera initialization failed: $e");
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Camera Error'),
            content: Text('Failed to initialize camera: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _resetCamera({bool force = false}) async {
    if (!_cameraReady && !force) {
      debugPrint("Camera reset skipped: camera not ready");
      return;
    }
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Resetting camera...'),
              ],
            ),
          ),
        );
      }
      debugPrint("Resetting camera...");
      await Future.delayed(const Duration(milliseconds: 1000));
      await _controller.setFocusMode(FocusMode.auto);
      await _controller.setFocusPoint(const Offset(0.5, 0.5));
      await _controller.setExposureMode(ExposureMode.auto);
      await _controller.setExposureOffset(0.2);
      debugPrint("Camera reset: focus=auto, focusPoint=(0.5, 0.5), exposure=auto, offset=0.2");
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Camera reset failed: $e");
      if (mounted) {
        Navigator.pop(context);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Camera Reset Error'),
            content: Text('Failed to reset camera: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      debugPrint("Forcing camera reinitialization...");
      await _controller.dispose();
      await _initCamera();
      debugPrint("Camera reinitialized after reset failure");
    }
  }

  Future<void> _startFaceSizeCheck() async {
    while (mounted && _runFaceSizeCheck) {
      if (!_isProcessing && _cameraReady) {
        final bytes = await _captureJpegBytes(silent: true);
        if (bytes != null) {
          final isProper = await _faceService.isFaceProperlySized(bytes);
          if (mounted) {
            setState(() {
              _isFaceProper = isProper;
              _isFaceProperNotifier.value = isProper;
            });
            debugPrint("Face proper: $isProper");
          }
        } else {
          if (mounted) {
            setState(() {
              _isFaceProper = false;
              _isFaceProperNotifier.value = false;
            });
            debugPrint("No face detected: capture failed");
          }
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<Uint8List?> _captureJpegBytes({bool silent = false}) async {
    try {
      if (!_cameraReady) {
        debugPrint("Capture skipped: camera not ready");
        if (!silent) _snack('Camera not ready');
        return null;
      }
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
        _snack('Capture error: $e');
      }
      return null;
    } finally {
      await _resetCamera(force: true);
    }
  }

  Future<void> _captureFaceForRegistration(String name, String rollNo) async {
    if (_isProcessing) {
      _snack('Processing in progress, please wait...');
      debugPrint("Capture skipped: already processing");
      return;
    }
    if (!_isFaceProper) {
      _snack('Please adjust face to 30-50 cm, center in frame');
      debugPrint("Capture skipped: improper face size");
      setState(() => _showSingleButton = false);
      return;
    }
    _isProcessing = true;
    _isProcessingNotifier.value = true;
    _runFaceSizeCheck = false;

    try {
      await _resetCamera(force: true);
      final bytes = await _captureJpegBytes();
      if (bytes == null) {
        _snack('Failed to capture image.');
        debugPrint("Registration capture failed");
        setState(() => _showSingleButton = false);
        return;
      }
      setState(() {
        _pendingName = name;
        _pendingRollNo = rollNo;
        _pendingImageBytes = bytes;
        _showSingleButton = true;
      });
      _snack('Face captured. Press Register Face to submit.');
      debugPrint("Face captured for registration: $name, Roll: $rollNo");
    } catch (e) {
      _snack('Error: $e');
      debugPrint("Error in _captureFaceForRegistration: $e");
      setState(() => _showSingleButton = false);
    } finally {
      _isProcessing = false;
      _isProcessingNotifier.value = false;
      _runFaceSizeCheck = true;
    }
  }

  Future<void> _registerStudent() async {
    if (_isProcessing) {
      _snack('Processing in progress, please wait...');
      debugPrint("Registration skipped: already processing");
      return;
    }
    if (!_isFaceProper) {
      _snack('Please adjust face to 30-50 cm, center in frame');
      debugPrint("Registration skipped: improper face size");
      setState(() => _showSingleButton = false);
      return;
    }
    if (_pendingName == null || _pendingRollNo == null || _pendingImageBytes == null) {
      _snack('No face data to register');
      debugPrint("Registration failed: missing form data or image");
      setState(() => _showSingleButton = false);
      return;
    }
    _isProcessing = true;
    _isProcessingNotifier.value = true;
    _runFaceSizeCheck = false;

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Registering student...'),
              ],
            ),
          ),
        );
      }
      debugPrint("Processing face for student registration...");
      final embedding = await _faceService.processFace(_pendingImageBytes!);
      if (embedding == null) {
        _snack('Failed to process face.');
        debugPrint("Face embedding returned null");
        return;
      }

      debugPrint("Face embedding generated successfully, registering via API...");
      final success = await _api.registerStudent(
        name: _pendingName!,
        rollNo: _pendingRollNo!,
        classId: classId,
        embedding: embedding,
      );

      if (success) {
        _snack('Student registered');
        debugPrint("Student registered successfully: $_pendingName");
        await Future.delayed(const Duration(seconds: 5)); // 5-second loading
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
        }
      } else {
        _snack('Register failed');
        debugPrint("API registration failed for $_pendingName");
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
        }
      }
    } catch (e) {
      _snack('Error: $e');
      debugPrint("Error in _registerStudent: $e");
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
    } finally {
      _isProcessing = false;
      _isProcessingNotifier.value = false;
      _runFaceSizeCheck = true;
      setState(() {
        _pendingName = null;
        _pendingRollNo = null;
        _pendingImageBytes = null;
        _showSingleButton = false;
      });
    }
  }

  Future<void> _takeAttendance() async {
    if (_isProcessing) {
      _snack('Processing in progress, please wait...');
      debugPrint("Attendance skipped: already processing");
      return;
    }
    if (!_isFaceProper) {
      _snack('Please adjust face to 30-50 cm, center in frame');
      debugPrint("Attendance skipped: improper face size");
      setState(() => _showSingleButton = false);
      return;
    }
    _isProcessing = true;
    _isProcessingNotifier.value = true;
    _runFaceSizeCheck = false;

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
        debugPrint('Captured embedding: ${capturedEmbedding.take(10)}...');
        debugPrint('Stored embedding for ${s.name}: ${s.faceEmbedding.take(10)}...');
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
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('No Match Found'),
              content: Text('No match found. Best match: ${bestMatch?.name} (similarity: ${bestSim.toStringAsFixed(3)})'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          debugPrint("No match: best match ${bestMatch.name} (sim=$bestSim)");
        }
      } else {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No Match Found'),
            content: Text('No match found (best similarity: ${bestSim.toStringAsFixed(3)})'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        debugPrint("No matching student found. Best similarity: $bestSim");
      }
    } catch (e) {
      _snack('Error: $e');
      debugPrint("Error in _takeAttendance: $e");
    } finally {
      _isProcessing = false;
      _isProcessingNotifier.value = false;
      _runFaceSizeCheck = true;
      setState(() {
        _pendingName = null;
        _pendingRollNo = null;
        _pendingImageBytes = null;
        _showSingleButton = false;
      });
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
          : Stack(
        children: [
          CameraPreviewWidget(
            controller: _controller,
            isProcessingNotifier: _isProcessingNotifier,
            isFaceProperNotifier: _isFaceProperNotifier,
          ),
          ActionButtonsWidget(
            isProcessing: _isProcessing,
            isFaceProper: _isFaceProper,
            showSingleButton: _showSingleButton,
            onRegister: () async {
              await showDialog(
                context: context,
                builder: (ctx) => RegisterDialogWidget(
                  onProceed: (name, rollNo) async {
                    await _captureFaceForRegistration(name, rollNo);
                  },
                ),
              );
            },
            onTakeAttendance: _showSingleButton ? _registerStudent : _takeAttendance,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    debugPrint("Disposing camera and face service...");
    _controller.dispose();
    _faceService.dispose();
    _isProcessingNotifier.dispose();
    _isFaceProperNotifier.dispose();
    super.dispose();
  }
}