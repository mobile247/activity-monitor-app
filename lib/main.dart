// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'services/activity_monitor_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activity Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ActivityMonitorScreen(),
    );
  }
}

class ActivityMonitorScreen extends StatefulWidget {
  const ActivityMonitorScreen({super.key});

  @override
  State<ActivityMonitorScreen> createState() => _ActivityMonitorScreenState();
}

class _ActivityMonitorScreenState extends State<ActivityMonitorScreen> {
  final ActivityMonitorService _service = ActivityMonitorService();
  bool _isInitialized = false;
  bool _isLoading = true;
  String _errorMessage = '';

  // Settings
  int _saveInterval = 5; // default 5 minutes
  int _statsRefreshInterval = 1; // default 1 second

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _service.initialize();
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize: ${e.toString()}';
      });
    }
  }

  Future<void> _toggleMonitoring() async {
    if (_service.isMonitoring) {
      await _service.stopMonitoring();
    } else {
      await _service.startMonitoring(
        statsRefreshSeconds: _statsRefreshInterval,
        saveIntervalMinutes: _saveInterval,
      );
    }
    // Force UI update
    setState(() {});
  }

  Future<void> _resetCounters() async {
    _service.resetCounters();
  }

  Future<void> _openLogFile() async {
    final logPath = await _service.getLogFilePath();
    final file = File(logPath);

    if (await file.exists()) {
      if (Platform.isWindows) {
        Process.run('explorer.exe', ['/select,', logPath]);
      } else if (Platform.isMacOS) {
        Process.run('open', ['-R', logPath]);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log file does not exist yet')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(_errorMessage),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeService,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Get the platform-specific title suffix
    final platformSuffix = Platform.isWindows ? 'Windows' : 'macOS';

    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Monitor ($platformSuffix)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Monitoring:'),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<bool>(
                          valueListenable: _service.isActive,
                          builder: (context, isActive, _) {
                            return Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    _service.isMonitoring
                                        ? (isActive
                                            ? Colors.green
                                            : Colors.orange)
                                        : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _service.isMonitoring ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                _service.isMonitoring
                                    ? Colors.green
                                    : Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _toggleMonitoring,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _service.isMonitoring
                                    ? Colors.red.shade100
                                    : Colors.green.shade100,
                            foregroundColor:
                                _service.isMonitoring
                                    ? Colors.red
                                    : Colors.green,
                          ),
                          child: Text(_service.isMonitoring ? 'Stop' : 'Start'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Activity stats card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Activity Statistics',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _resetCounters,
                          tooltip: 'Reset Counters',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                      context,
                      'Keyboard Events:',
                      _service.keyboardCount,
                      Icons.keyboard,
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                      context,
                      'Mouse Events:',
                      _service.mouseCount,
                      Icons.mouse,
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                      context,
                      'Idle Time:',
                      _service.idleTime,
                      Icons.timer_outlined,
                      suffix: ' seconds',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Logs card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Logs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Save Interval:'),
                        const SizedBox(width: 8),
                        Text(
                          '$_saveInterval minutes',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Open Log File'),
                          onPressed: _openLogFile,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Footer with save interval slider
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Save Interval: $_saveInterval minutes'),
                        ),
                      ],
                    ),
                    Slider(
                      min: 1,
                      max: 60,
                      divisions: 59,
                      value: _saveInterval.toDouble(),
                      label: '$_saveInterval minutes',
                      onChanged: (value) {
                        setState(() {
                          _saveInterval = value.round();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    ValueNotifier<int> valueNotifier,
    IconData icon, {
    String suffix = '',
  }) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        ValueListenableBuilder<int>(
          valueListenable: valueNotifier,
          builder: (context, value, _) {
            return Text(
              '$value$suffix',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            );
          },
        ),
      ],
    );
  }
}
