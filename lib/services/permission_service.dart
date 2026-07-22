import 'dart:io';

/// Permission ACCESS_LOCAL_NETWORK belum tersedia di Android manapun saat ini
/// (dijadwalkan API 36 yang belum rilis publik).
/// Class ini dipertahankan agar tidak ada compile error, tapi semua method
/// langsung return true tanpa melakukan apapun.
class PermissionService {
  static bool _granted = false;

  static Future<bool> requestOnAppStart() async {
    _granted = true;
    return true;
  }

  static Future<bool> requestLocalNetworkPermission() async {
    _granted = true;
    return true;
  }

  static bool get isGranted => _granted;
  static bool get hasRequested => true;
}
