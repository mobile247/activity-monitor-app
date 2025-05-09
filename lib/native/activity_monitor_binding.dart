// lib/native/activity_monitor_binding.dart
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

/// Defines the FFI bindings to the Rust library
class ActivityMonitorBindings {
  // Singleton instance
  static final ActivityMonitorBindings _instance =
      ActivityMonitorBindings._internal();
  factory ActivityMonitorBindings() => _instance;
  ActivityMonitorBindings._internal();

  // Library handler
  late final DynamicLibrary _lib;

  // Function signatures
  late final _startMonitoringFunc = _lib
      .lookupFunction<Bool Function(), bool Function()>('start_monitoring');
  late final _stopMonitoringFunc = _lib
      .lookupFunction<Bool Function(), bool Function()>('stop_monitoring');
  late final _getKeyboardCountFunc = _lib
      .lookupFunction<Uint64 Function(), int Function()>('get_keyboard_count');
  late final _getMouseCountFunc = _lib
      .lookupFunction<Uint64 Function(), int Function()>('get_mouse_count');
  late final _getIdleTimeFunc = _lib
      .lookupFunction<Uint64 Function(), int Function()>('get_idle_time');
  late final _resetCountersFunc = _lib
      .lookupFunction<Void Function(), void Function()>('reset_counters');
  late final _saveActivityLogFunc = _lib.lookupFunction<
    Bool Function(Pointer<Uint8>, IntPtr),
    bool Function(Pointer<Uint8>, int)
  >('save_activity_log');

  // Public API
  bool get isInitialized => _lib != null;

  /// Initialize the library
  Future<void> initialize() async {
    if (Platform.isWindows) {
      try {
        // First try to load from the expected path
        _lib = DynamicLibrary.open('activity_monitor.dll');
      } catch (e) {
        // If that fails, try to load from the bundled location
        _lib = DynamicLibrary.open(
          '${Directory.current.path}\\activity_monitor.dll',
        );
      }
    } else if (Platform.isMacOS) {
      try {
        // First try to load from the standard path
        _lib = DynamicLibrary.open('libactivity_monitor.dylib');
      } catch (e) {
        // If that fails, try to load from the app bundle
        final bundle = Directory(Platform.resolvedExecutable).parent.parent;
        final frameworksDir = Directory('${bundle.path}/Frameworks');
        _lib = DynamicLibrary.open(
          '${frameworksDir.path}/libactivity_monitor.dylib',
        );
      }
    } else {
      throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}',
      );
    }
  }

  /// Start monitoring keyboard and mouse activity
  bool startMonitoring() {
    return _startMonitoringFunc();
  }

  /// Stop monitoring keyboard and mouse activity
  bool stopMonitoring() {
    return _stopMonitoringFunc();
  }

  /// Get the number of keyboard events recorded
  int getKeyboardCount() {
    return _getKeyboardCountFunc();
  }

  /// Get the number of mouse events recorded
  int getMouseCount() {
    return _getMouseCountFunc();
  }

  /// Get the idle time in seconds
  int getIdleTime() {
    return _getIdleTimeFunc();
  }

  /// Reset all counters
  void resetCounters() {
    _resetCountersFunc();
  }

  /// Save the activity log to a file
  Future<bool> saveActivityLog(String filePath) async {
    final pathPointer = filePath.toNativeUtf8();
    try {
      return _saveActivityLogFunc(pathPointer.cast<Uint8>(), filePath.length);
    } finally {
      malloc.free(pathPointer);
    }
  }

  /// Get the default log file path
  Future<String> getDefaultLogPath() async {
    Directory? dir;

    if (Platform.isWindows) {
      // On Windows, use the AppData folder
      final appDataDir = Platform.environment['APPDATA'];
      if (appDataDir != null) {
        dir = Directory('$appDataDir\\ActivityMonitor');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
    } else {
      // On macOS, use the standard Documents directory
      dir = await getApplicationDocumentsDirectory();
    }

    final logDir = Directory(path.join(dir.path, 'activity_logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    return path.join(logDir.path, 'activity_log.csv');
  }
}
