import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

typedef Callback = void Function(String? screenshotPath);

class ScreenshotCallback {
  static const MethodChannel _channel =
      const MethodChannel('flutter.moum/screenshot_callback');

  /// Functions to execute when callback fired.
  List<Callback> _callbacks = [];

  ScreenshotCallback() {
    initialize();
  }

  /// Initializes screenshot callback plugin.
  Future<void> initialize() async {
    if (Platform.isAndroid) {
      await Permission.mediaLibrary.request();
      await Permission.storage.request();
      // await Permission.manageExternalStorage.request();
      await Permission.photos.request();
    }
    _channel.setMethodCallHandler(_handleMethod);
    await _channel.invokeMethod('initialize');
  }

  /// Add callback.
  void addListener(Callback callback) {
    _callbacks.add(callback);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onCallback':
        for (final callback in _callbacks) {
          callback(call.arguments);
        }
        break;
      default:
        throw ('method not defined');
    }
  }

  /// Remove callback listener.
  Future<void> dispose() async {
    _callbacks.clear();
    await _channel.invokeMethod('dispose');
  }
}
