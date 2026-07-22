import 'package:flutter/services.dart';

/// Android 16+ memperkenalkan permission ACCESS_LOCAL_NETWORK yang wajib
/// diminta secara runtime agar socket ke IP lokal tidak gagal diam-diam
/// (lihat pembahasan sebelumnya).
class PermissionService {
  static const _channel = MethodChannel('cerdas_cermat_buzzer/permissions');

  static Future<bool> requestLocalNetworkPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestLocalNetwork');
      return granted ?? true;
    } catch (_) {
      // Device dengan Android < 16 tidak punya permission ini, anggap aman.
      return true;
    }
  }
}
