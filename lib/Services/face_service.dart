import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceService {
  final FaceDetector _detector;
  Interpreter? _interpreter;
  bool _busy = false;
  bool ready = false; // <--- add ready flag

  FaceService()
      : _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  ) {
    _loadModel();
  }

  Future<void> init() async {
    debugPrint('Loading TFLite model...');
    final modelData = await rootBundle.load('Assets/Models/facenet.tflite');
    _interpreter = await Interpreter.fromBuffer(modelData.buffer.asUint8List());
    ready = true;
    debugPrint('TFLite model loaded and ready');
  }

  Future<void> _loadModel() async {
    debugPrint('Loading TFLite model...');
    final modelData = await rootBundle.load('Assets/Models/facenet.tflite');
    _interpreter = await Interpreter.fromBuffer(modelData.buffer.asUint8List());
    ready = true; // mark interpreter ready
    debugPrint('TFLite model loaded and ready');
  }

  /// Accept bytes directly
  Future<List<double>?> processFace(Uint8List jpegBytes) async {
    debugPrint('Start processing face, bytes length=${jpegBytes.length}');

    // Wait for interpreter
    while (!ready) {
      debugPrint('Waiting for interpreter...');
      await Future.delayed(const Duration(milliseconds: 10000));
    }

    if (_busy) {
      debugPrint('Interpreter busy');
      return null;
    }

    _busy = true;

    try {
      final decoded = img.decodeImage(jpegBytes);
      if (decoded == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      // Save temp file for ML Kit
      final tempFile = File('${Directory.systemTemp.path}/tmp_face.jpg');
      await tempFile.writeAsBytes(jpegBytes);
      final inputImage = InputImage.fromFilePath(tempFile.path);

      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) {
        debugPrint('No face detected');
        return null;
      }

      final face = faces.first;
      debugPrint('Face detected: boundingBox=${face.boundingBox}');

      final rect = face.boundingBox;
      final cropX = rect.left.toInt().clamp(0, decoded.width - 1);
      final cropY = rect.top.toInt().clamp(0, decoded.height - 1);
      final cropWidth = math.min(rect.width.toInt(), decoded.width - cropX);
      final cropHeight = math.min(rect.height.toInt(), decoded.height - cropY);


      final cropRect = img.copyCrop(
        decoded, cropX, cropY, cropWidth, cropHeight,
      );
      final resized = img.copyResize(cropRect, width: 160, height: 160);

      final input = _imageToFloat32(resized);
      final output = List.filled(128, 0.0).reshape([1, 128]);
      _interpreter!.run(input, output);
      debugPrint('Embedding generated');

      return _l2Normalize(List<double>.from(output[0]));
    } catch (e) {
      debugPrint('Face processing error: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  List<List<List<List<double>>>> _imageToFloat32(img.Image image) {
    const mean = 127.5;
    const std = 127.5;

    final data = List.generate(
      1,
          (_) => List.generate(
        160,
            (_) => List.generate(
          160,
              (_) => List.filled(3, 0.0),
        ),
      ),
    );

    for (int y = 0; y < 160; y++) {
      for (int x = 0; x < 160; x++) {
        final pixel = image.getPixel(x, y);

        // Extract channels from packed int pixel
        final r = img.getRed(pixel).toDouble();
        final g = img.getGreen(pixel).toDouble();
        final b = img.getBlue(pixel).toDouble();

        data[0][y][x][0] = (r - mean) / std;
        data[0][y][x][1] = (g - mean) / std;
        data[0][y][x][2] = (b - mean) / std;
      }
    }
    return data;
  }

  List<double> _l2Normalize(List<double> embedding) {
    final sum = embedding.fold<double>(0.0, (a, b) => a + b * b);
    final norm = math.sqrt(sum);
    return embedding.map((e) => e / norm).toList();
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0, magA = 0.0, magB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    return dot / (math.sqrt(magA) * math.sqrt(magB));
  }

  void dispose() {
    _detector.close();
    _interpreter?.close();
    debugPrint('FaceService disposed');
  }
}

