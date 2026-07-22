import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../data/network/socket_server_service.dart';
import '../../../data/models/group_model.dart';
import '../../../data/models/round_result_model.dart';
import '../../../data/local/round_history_repository.dart';
import '../../../services/permission_service.dart';

class AdminController extends ChangeNotifier {
  final SocketServerService _server = SocketServerService();
  final RoundHistoryRepository _historyRepo = RoundHistoryRepository();

  List<GroupModel> groups = [];
  String? lastWinnerLabel;
  int roundNumber = 1;
  String? serverIp;
  bool isServerRunning = false;

  Future<void> startServer() async {
    await PermissionService.requestLocalNetworkPermission();

    serverIp = await _getLocalIp();
    isServerRunning = false;
    notifyListeners();

    _server.onGroupsUpdated = (updatedGroups) {
      groups = List<GroupModel>.from(updatedGroups);
      notifyListeners();
    };

    _server.onRoundWinner = (winnerGroupId, pressOrder) async {
      final winnerLabel = groups
          .firstWhere(
            (g) => g.id == winnerGroupId,
            orElse: () => GroupModel(id: '', label: 'Unknown'),
          )
          .label;
      lastWinnerLabel = winnerLabel;
      notifyListeners();

      final labels = pressOrder.map((id) {
        return groups
            .firstWhere(
              (g) => g.id == id,
              orElse: () => GroupModel(id: id, label: id),
            )
            .label;
      }).toList();

      await _historyRepo.addResult(
        RoundResultModel(
          roundNumber: roundNumber,
          winnerGroupLabel: winnerLabel,
          timestamp: DateTime.now(),
          pressOrderLog: labels,
        ),
      );
    };

    await _server.start();
    isServerRunning = true;
    notifyListeners();
  }

  /// Deteksi IP hotspot dengan prioritas yang lebih akurat.
  /// Android hotspot biasanya di interface bernama "wlan0", "ap0", atau "swlan0".
  /// IP hotspot hampir selalu 192.168.43.1 atau 192.168.x.1 (gateway-ending).
  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String? wifiIp;
      String? fallbackIp;

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.isEmpty || addr.isLoopback) continue;

          // Prioritas 1: IP hotspot klasik Android (192.168.43.x)
          if (ip.startsWith('192.168.43.')) return ip;

          // Prioritas 2: IP yang berakhiran .1 di subnet 192.168 → kemungkinan gateway hotspot
          if (ip.startsWith('192.168.') && ip.endsWith('.1')) return ip;

          // Prioritas 3: IP WiFi biasa 192.168.x.x
          if (ip.startsWith('192.168.') && wifiIp == null) wifiIp = ip;

          // Fallback: IP apapun yang bukan loopback
          fallbackIp ??= ip;
        }
      }
      return wifiIp ?? fallbackIp;
    } catch (_) {}
    return null;
  }

  void renameGroup(String groupId, String newLabel) {
    _server.renameGroup(groupId, newLabel);
  }

  Future<void> kickGroup(String groupId) async {
    await _server.kickGroup(groupId);
  }

  void resetRound() {
    // Reset server DULU sebelum update state lokal
    _server.resetRound();
    // Baru update state controller
    lastWinnerLabel = null;
    roundNumber++;
    groups = List<GroupModel>.from(_server.groups);
    notifyListeners();
  }

  List<RoundResultModel> getHistory() => _historyRepo.getAllResults();

  @override
  void dispose() {
    // stop() adalah async — fire-and-forget di dispose() sudah cukup
    // karena Flutter memanggil dispose hanya setelah widget benar-benar unmount.
    // unawaited() tidak tersedia tanpa import, gunakan dummy assignment.
    _server.stop().ignore();
    super.dispose();
  }
}
