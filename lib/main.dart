import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'src/utils/test_harness.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Sprint1TestScreen());
  }
}

class Sprint1TestScreen extends StatefulWidget {
  const Sprint1TestScreen({super.key});

  @override
  State<Sprint1TestScreen> createState() => _Sprint1TestScreenState();
}

class _Sprint1TestScreenState extends State<Sprint1TestScreen> {
  final _harness = Sprint1TestHarness();
  bool _isLoading = false;

  Future<void> _pickAndTestFile() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        // Kick off the local execution loop pipeline
        await _harness.runLocalExecutionLoop(result.files.single.path!);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sprint 1 Local Test Pipeline')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: _pickAndTestFile,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Select File & Run Loop'),
              ),
      ),
    );
  }
}
