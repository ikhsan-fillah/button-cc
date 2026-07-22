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
      // Buat list baru agar widget mendeteksi perubahan
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

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.43') || ip.startsWith('192.168.')) {
            return ip;
          }
        }
      }
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

  /// Kick peserta dari server
  Future<void> kickGroup(String groupId) async {
    await _server.kickGroup(groupId);
    // groups akan diupdate otomatis via onGroupsUpdated callback
  }

  void resetRound() {
    lastWinnerLabel = null;
    roundNumber++;
    _server.resetRound();
    // Buat list baru agar setState() mendeteksi perubahan
    groups = List<GroupModel>.from(_server.groups);
    notifyListeners();
  }

  List<RoundResultModel> getHistory() => _historyRepo.getAllResults();

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }
}
