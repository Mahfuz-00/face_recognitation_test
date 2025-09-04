import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Runs model inference in background isolate
Future<List<dynamic>> runModelInBackground(CameraImage image) async {
  return await Isolate.run(() => _tfliteInference(image));
}

/// Convert CameraImage (YUV) to Float32 input for model
Uint8List _preprocess(CameraImage image) {
  // Example: grayscale conversion (adjust for your model input!)
  final int width = image.width;
  final int height = image.height;

  final bytes = Uint8List(width * height);
  final plane = image.planes[0].bytes; // Y plane (luminance)
  for (int i = 0; i < width * height; i++) {
    bytes[i] = plane[i];
  }

  return bytes;
}

/// Runs inference using tflite_flutter
Future<List<dynamic>> _tfliteInference(CameraImage image) async {
  try {
    // Load interpreter (keeps cached after first load)
    final modelData = await rootBundle.load('Assets/Models/facenet.tflite');
    final _interpreter = await Interpreter.fromBuffer(modelData.buffer.asUint8List());
    // Preprocess image into model input
    Uint8List inputBytes = _preprocess(image);

    // Example: assuming model expects [1, 224, 224, 1]
    var input = inputBytes.buffer.asUint8List();
    var output = List.filled(1 * 128, 0).reshape([1, 128]); // adjust for your model output

    // Run inference
    _interpreter.run(input, output);

    return output[0];
  } catch (e) {
    print("TFLite inference error: $e");
    return [];
  }
}
