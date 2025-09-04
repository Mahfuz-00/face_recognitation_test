import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';


import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:http/http.dart' as http;

import 'Screens/face_home.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(FaceApp(cameras: cameras));
}


class FaceApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const FaceApp({super.key, required this.cameras});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Attendance',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: FaceHome(cameras: cameras),
    );
  }
}