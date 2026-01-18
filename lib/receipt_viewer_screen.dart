import 'dart:io';
import 'package:flutter/material.dart';

class ReceiptViewerScreen extends StatelessWidget {
  final String imagePath;

  const ReceiptViewerScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: Center(
        child: Image.file(File(imagePath)),
      ),
    );
  }
}
