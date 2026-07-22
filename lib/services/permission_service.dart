import 'dart:io';
import 'package:flutter/services.dart';

/// Menangani permission runtime yang dibutuhkan app.
/// Android 16+ (API 36+) memperkenalkan ACCESS_LOCAL_NETWORK yang wajib
/// diminta secara runtime agar socket ke IP lokal tidak gagal diam-diam.
class PermissionService {
  static const _channel = MethodChannel('cerdas_cermat_buzzer/permissions');

  static Future<bool> requestLocalNetworkPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('requestLocalNetwork');
      return granted ?? true;
    } on MissingPluginException {
      // Platform channel belum terdaftar (unit test / iOS)
      return true;
    } catch (_) {
      // Device dengan Android < 16 tidak punya permission ini, anggap aman
      return true;
    }
  }
}
