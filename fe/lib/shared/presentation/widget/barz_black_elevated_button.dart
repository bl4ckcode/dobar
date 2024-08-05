import 'package:flutter/material.dart';

class BarzBlackElevatedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const BarzBlackElevatedButton(
      {super.key, required this.onPressed, required this.text});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 5,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        textStyle: const TextStyle(fontSize: 16),
      ),
      child: Text(text),
    );
  }
}
