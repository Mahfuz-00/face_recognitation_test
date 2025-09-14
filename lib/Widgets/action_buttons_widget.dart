import 'package:flutter/material.dart';

class ActionButtonsWidget extends StatelessWidget {
  final bool isProcessing;
  final bool isFaceProper;
  final bool showSingleButton;
  final VoidCallback onRegister;
  final VoidCallback onTakeAttendance;

  const ActionButtonsWidget({
    super.key,
    required this.isProcessing,
    required this.isFaceProper,
    required this.showSingleButton,
    required this.onRegister,
    required this.onTakeAttendance,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: showSingleButton
              ? FilledButton(
            onPressed: isProcessing || !isFaceProper ? null : onTakeAttendance,
            style: FilledButton.styleFrom(
              minimumSize: const Size(160, 48),
            ),
            child: const Text('Register Face'),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton.tonal(
                onPressed: isProcessing || !isFaceProper ? null : onRegister,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 48),
                ),
                child: const Text('Register'),
              ),
              FilledButton(
                onPressed: isProcessing || !isFaceProper ? null : onTakeAttendance,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 48),
                ),
                child: const Text('Take Attendance'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}