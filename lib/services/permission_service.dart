import 'dart:io';
import 'package:flutter/services.dart';

class PermissionService {
  static const _channel = MethodChannel('cerdas_cermat_buzzer/permissions');
  static bool _granted = false;
  static bool _requested = false;

  /// Dipanggil saat layar pertama dibuka (initState).
  /// Menampilkan dialog permission sebelum user melakukan apapun.
  static Future<bool> requestOnAppStart() async {
    if (!Platform.isAndroid) {
      _granted = true;
      return true;
    }
    if (_granted) return true;
    _requested = true;
    try {
      final result = await _channel.invokeMethod<bool>('requestLocalNetwork');
      _granted = result ?? true;
      return _granted;
    } on MissingPluginException {
      _granted = true;
      return true;
    } catch (_) {
      // Android < API 36: permission tidak ada, anggap granted
      _granted = true;
      return true;
    }
  }

  /// Dipakai sebelum connect/startServer — cukup return cached result.
  static Future<bool> requestLocalNetworkPermission() async {
    if (!Platform.isAndroid) return true;
    if (_granted) return true;
    return requestOnAppStart();
  }

  static bool get isGranted => _granted;
  static bool get hasRequested => _requested;
}
