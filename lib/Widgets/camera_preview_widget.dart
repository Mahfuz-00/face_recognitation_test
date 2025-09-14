import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;
  final ValueNotifier<bool> isProcessingNotifier;
  final ValueNotifier<bool> isFaceProperNotifier;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    required this.isProcessingNotifier,
    required this.isFaceProperNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isProcessingNotifier,
      builder: (context, isProcessing, child) => ValueListenableBuilder<bool>(
        valueListenable: isFaceProperNotifier,
        builder: (context, isFaceProper, child) => Stack(
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.width * controller.value.aspectRatio,
                  child: CameraPreview(controller),
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
                      ? 'Face position OK (30-50 cm)'
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
          ],
        ),
      ),
    );
  }
}