import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceService {
  final FaceDetector _detector;
  Interpreter? _interpreter;
  bool _busy = false;
  bool ready = false;

  FaceService()
      : _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.2, // Increased for stricter face size
    ),
  );

  Future<void> loadModel(BuildContext context) async {
    debugPrint('Loading TFLite model...');
    try {
      final modelData = await DefaultAssetBundle.of(context).load('Assets/Models/facenet.tflite');
      final modelBytes = modelData.buffer.asUint8List();

      _interpreter = await Isolate.run(() async {
        final interpreter = await Interpreter.fromBuffer(modelBytes);
        return interpreter;
      });
      ready = true;
      debugPrint('TFLite model loaded and ready');
    } catch (e, stackTrace) {
      debugPrint('Failed to load TFLite model: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<List<double>?> processFace(Uint8List jpegBytes) async {
    debugPrint('Start processing face, bytes length=${jpegBytes.length}');

    while (!ready) {
      debugPrint('Waiting for interpreter...');
      await Future.delayed(const Duration(milliseconds: 100));
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
      debugPrint('Decoded image: width=${decoded.width}, height=${decoded.height}');

      // Pre-resize for high-resolution images
      final targetWidth = 720;
      final targetHeight = (decoded.height * targetWidth / decoded.width).round();
      final preResized = img.copyResize(decoded, width: targetWidth, height: targetHeight);
      final preResizedBytes = img.encodeJpg(preResized, quality: 90);
      debugPrint('Pre-resized image: width=${preResized.width}, height=${preResized.height}');

      // Save to temporary file for ML Kit
      final tempFile = File('${Directory.systemTemp.path}/tmp_face_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(preResizedBytes);
      final inputImage = InputImage.fromFilePath(tempFile.path);

      final faces = await _detector.processImage(inputImage);
      debugPrint('Detected ${faces.length} face(s)');

      if (faces.isEmpty) {
        debugPrint('No face detected');
        await tempFile.delete();
        return null;
      }

      final face = faces.first;
      final rect = face.boundingBox;
      debugPrint('Face detected: boundingBox=$rect');

      // Check face size (should be 20-50% of image width)
      final faceWidthPercent = rect.width / preResized.width;
      debugPrint('Face width percent: ${(faceWidthPercent * 100).toStringAsFixed(2)}%');
      if (faceWidthPercent < 0.2 || faceWidthPercent > 0.5) {
        debugPrint('Face size out of range: ${faceWidthPercent * 100}%');
        await tempFile.delete();
        return null;
      }

      // Adjust cropping for higher resolution
      final cropX = (rect.left - 50).toInt().clamp(0, preResized.width - 1);
      final cropY = (rect.top - 50).toInt().clamp(0, preResized.height - 1);
      final cropWidth = (rect.width + 100).toInt().clamp(0, preResized.width - cropX);
      final cropHeight = (rect.height + 100).toInt().clamp(0, preResized.height - cropY);
      debugPrint('Cropping: x=$cropX, y=$cropY, width=$cropWidth, height=$cropHeight');

      final cropRect = img.copyCrop(
        preResized,
        cropX,
        cropY,
        cropWidth,
        cropHeight,
      );
      final resized = img.copyResize(cropRect, width: 160, height: 160);
      debugPrint('Resized image: width=${resized.width}, height=${resized.height}');

      final input = _imageToFloat32(resized);
      final output = List.filled(512, 0.0).reshape([1, 512]);
      _interpreter!.run(input, output);
      final embedding = _l2Normalize(List<double>.from(output[0]));
      debugPrint('Embedding generated: ${embedding.take(10)}...');

      await tempFile.delete();
      return embedding;
    } catch (e) {
      debugPrint('Face processing error: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<bool> isFaceProperlySized(Uint8List jpegBytes) async {
    try {
      final decoded = img.decodeImage(jpegBytes);
      if (decoded == null) {
        debugPrint('Failed to decode image for size check');
        return false;
      }

      final targetWidth = 720;
      final targetHeight = (decoded.height * targetWidth / decoded.width).round();
      final preResized = img.copyResize(decoded, width: targetWidth, height: targetHeight);
      final preResizedBytes = img.encodeJpg(preResized, quality: 90);

      final tempFile = File('${Directory.systemTemp.path}/tmp_face_check_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(preResizedBytes);
      final inputImage = InputImage.fromFilePath(tempFile.path);

      final faces = await _detector.processImage(inputImage);
      await tempFile.delete();

      if (faces.isEmpty) {
        debugPrint('No face detected for size check');
        return false;
      }

      final face = faces.first;
      final faceWidthPercent = face.boundingBox.width / preResized.width;
      debugPrint('Face size check: ${(faceWidthPercent * 100).toStringAsFixed(2)}%');
      return faceWidthPercent >= 0.2 && faceWidthPercent <= 0.5;
    } catch (e) {
      debugPrint('Face size check error: $e');
      return false;
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
    return embedding.map((e) => norm == 0 ? e : e / norm).toList();
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