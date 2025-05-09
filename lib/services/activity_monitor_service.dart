// lib/services/activity_monitor_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../native/activity_monitor_binding.dart';

class ActivityMonitorService {
  final ActivityMonitorBindings _bindings = ActivityMonitorBindings();

  bool _isMonitoring = false;
  Timer? _statsTimer;
  Timer? _saveTimer;

  // Activity stats
  final ValueNotifier<int> keyboardCount = ValueNotifier(0);
  final ValueNotifier<int> mouseCount = ValueNotifier(0);
  final ValueNotifier<int> idleTime = ValueNotifier(0);
  final ValueNotifier<bool> isActive = ValueNotifier(false);

  // Settings
  int _saveIntervalMinutes = 5;

  // Additional stats for logging
  int _lastLoggedKeyboardCount = 0;
  int _lastLoggedMouseCount = 0;
  DateTime _lastLogTime = DateTime.now();

  // Initialization
  Future<void> initialize() async {
    await _bindings.initialize();
    await _ensureLogDirectoryExists();
  }

  // Start monitoring
  Future<bool> startMonitoring({
    int statsRefreshSeconds = 1,
    int saveIntervalMinutes = 5,
  }) async {
    if (_isMonitoring) return false;

    // Set save interval
    _saveIntervalMinutes = saveIntervalMinutes;

    // Reset counts and timing
    _resetInternalCounters();

    // Start monitoring in native library
    final success = _bindings.startMonitoring();
    if (!success) return false;

    _isMonitoring = true;

    // Start timers
    _statsTimer = Timer.periodic(
      Duration(seconds: statsRefreshSeconds),
      _updateStats,
    );
    _saveTimer = Timer.periodic(
      Duration(minutes: _saveIntervalMinutes),
      _saveLog,
    );

    return true;
  }

  // Stop monitoring
  Future<bool> stopMonitoring() async {
    if (!_isMonitoring) return false;

    // Stop timers
    _statsTimer?.cancel();
    _statsTimer = null;

    _saveTimer?.cancel();
    _saveTimer = null;

    // Save one last time
    await _saveLog(null);

    // Stop monitoring in native library
    final success = _bindings.stopMonitoring();
    if (success) {
      _isMonitoring = false;
    }

    return success;
  }

  // Reset counters in UI and native library
  void resetCounters() {
    _bindings.resetCounters();
    _resetInternalCounters();
    keyboardCount.value = 0;
    mouseCount.value = 0;
    idleTime.value = 0;
  }

  // Reset just the internal counters used for logging
  void _resetInternalCounters() {
    _lastLoggedKeyboardCount = 0;
    _lastLoggedMouseCount = 0;
    _lastLogTime = DateTime.now();
  }

  // Update stats from native library
  void _updateStats(Timer timer) {
    keyboardCount.value = _bindings.getKeyboardCount();
    mouseCount.value = _bindings.getMouseCount();
    idleTime.value = _bindings.getIdleTime();

    // Consider active if idle time is less than 5 minutes (300 seconds)
    isActive.value = idleTime.value < 300;
  }

  // Save activity log and reset counters
  Future<bool> _saveLog(Timer? timer) async {
    if (!_isMonitoring) return false;

    // Get current counts before resetting
    final currentKeyboardCount = _bindings.getKeyboardCount();
    final currentMouseCount = _bindings.getMouseCount();
    final currentIdleTime = _bindings.getIdleTime();

    // Calculate activity in this interval
    final intervalKeyboardCount =
        currentKeyboardCount - _lastLoggedKeyboardCount;
    final intervalMouseCount = currentMouseCount - _lastLoggedMouseCount;

    // Calculate time since last log
    final now = DateTime.now();
    final intervalSeconds = now.difference(_lastLogTime).inSeconds;

    // Create log entry with interval data
    final logPath = await _bindings.getDefaultLogPath();
    final logDir = Directory(path.dirname(logPath));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    // Append the log entry
    try {
      final file = File(logPath);
      final exists = await file.exists();

      if (!exists) {
        // Create file with header
        await file.writeAsString(
          'timestamp,keyboard_events,mouse_events,idle_time_seconds,interval_seconds\n',
        );
      }

      // Add log entry
      final timestamp = now.millisecondsSinceEpoch ~/ 1000;
      final logEntry =
          '$timestamp,$intervalKeyboardCount,$intervalMouseCount,$currentIdleTime,$intervalSeconds\n';
      await file.writeAsString(logEntry, mode: FileMode.append);

      // Reset native counters
      _bindings.resetCounters();

      // Update last logged values
      _lastLoggedKeyboardCount = 0;
      _lastLoggedMouseCount = 0;
      _lastLogTime = now;

      return true;
    } catch (e) {
      print('Error saving log: $e');
      return false;
    }
  }

  // Get the path to the activity log file
  Future<String> getLogFilePath() async {
    return _bindings.getDefaultLogPath();
  }

  // Ensure log directory exists
  Future<void> _ensureLogDirectoryExists() async {
    final logPath = await _bindings.getDefaultLogPath();
    final directory = Directory(path.dirname(logPath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  // Check if the service is currently monitoring
  bool get isMonitoring => _isMonitoring;

  // Get the save interval in minutes
  int get saveIntervalMinutes => _saveIntervalMinutes;
}
