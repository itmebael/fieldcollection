import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Debug wrapper that adds error boundaries and performance monitoring
class DebugWrapper extends StatelessWidget {
  final Widget child;
  
  const DebugWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      return ErrorBoundary(
        child: PerformanceMonitor(
          child: child,
        ),
      );
    }
    return child;
  }
}

/// Error boundary widget to catch and log errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  
  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  @override
  void initState() {
    super.initState();
    FlutterError.onError = (FlutterErrorDetails details) {
      print('Flutter Error: ${details.exception}');
      print('Stack: ${details.stack}');
    };
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Performance monitor to track widget rebuilds
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  
  const PerformanceMonitor({super.key, required this.child});

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  int _buildCount = 0;
  DateTime _lastBuild = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    _buildCount++;
    
    if (_buildCount % 100 == 0) {
      print('Performance: Build count: $_buildCount, Time since last: ${now.difference(_lastBuild).inMilliseconds}ms');
    }
    
    _lastBuild = now;
    return widget.child;
  }
}