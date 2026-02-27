import 'package:flutter/material.dart';

/// Minimal test widget to help isolate EGL context issues
class EGLTestWidget extends StatefulWidget {
  const EGLTestWidget({super.key});

  @override
  State<EGLTestWidget> createState() => _EGLTestWidgetState();
}

class _EGLTestWidgetState extends State<EGLTestWidget> {
  int _counter = 0;

  void _incrementCounter() {
    if (mounted) {
      setState(() {
        _counter++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EGL Test - Minimal UI'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('EGL Context Test'),
            const SizedBox(height: 20),
            Text('Counter: $_counter'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _incrementCounter,
              child: const Text('Increment'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Main'),
            ),
          ],
        ),
      ),
    );
  }
}