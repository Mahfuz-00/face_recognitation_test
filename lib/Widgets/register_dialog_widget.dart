import 'package:flutter/material.dart';

class RegisterDialogWidget extends StatefulWidget {
  final Function(String, String) onProceed;

  const RegisterDialogWidget({super.key, required this.onProceed});

  @override
  State<RegisterDialogWidget> createState() => _RegisterDialogWidgetState();
}

class _RegisterDialogWidgetState extends State<RegisterDialogWidget> {
  final nameCtrl = TextEditingController();
  final rollCtrl = TextEditingController();
  bool canProceed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Register Student'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (value) {
              setState(() {
                canProceed = nameCtrl.text.trim().isNotEmpty && rollCtrl.text.trim().isNotEmpty;
              });
            },
          ),
          TextField(
            controller: rollCtrl,
            decoration: const InputDecoration(labelText: 'Roll No'),
            onChanged: (value) {
              setState(() {
                canProceed = nameCtrl.text.trim().isNotEmpty && rollCtrl.text.trim().isNotEmpty;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canProceed
              ? () {
            Navigator.pop(context);
            debugPrint("Proceeding with registration: ${nameCtrl.text}, Roll: ${rollCtrl.text}");
            widget.onProceed(nameCtrl.text.trim(), rollCtrl.text.trim());
          }
              : null,
          child: const Text('Proceed'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    rollCtrl.dispose();
    super.dispose();
  }
}