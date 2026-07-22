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

    // Ambil IP hotspot/WiFi yang aktif
    serverIp = await _getLocalIp();
    isServerRunning = false;
    notifyListeners();

    _server.onGroupsUpdated = (updatedGroups) {
      groups = updatedGroups;
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

  /// Ambil IP lokal aktif (WiFi hotspot biasanya 192.168.43.1)
  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      // Prioritaskan interface hotspot (wlan ap) atau WiFi
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          // Hotspot Android biasanya 192.168.43.x atau 192.168.x.1
          if (ip.startsWith('192.168.43') || ip.startsWith('192.168.')) {
            return ip;
          }
        }
      }
      // Fallback: ambil IP pertama yang bukan loopback
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  void renameGroup(String groupId, String newLabel) {
    _server.renameGroup(groupId, newLabel);
  }

  void resetRound() {
    _server.resetRound();
    lastWinnerLabel = null;
    roundNumber++;
    notifyListeners();
  }

  List<RoundResultModel> getHistory() => _historyRepo.getAllResults();

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }
}
