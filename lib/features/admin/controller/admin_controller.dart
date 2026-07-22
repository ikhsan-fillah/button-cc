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
  List<String> lastPressOrderLabels = []; // urutan pencetan ronde terakhir
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

    _server.onRoundWinner = (winnerGroupId, pressOrderLabels) async {
      final winnerLabel = groups
          .firstWhere(
            (g) => g.id == winnerGroupId,
            orElse: () => GroupModel(id: '', label: 'Unknown'),
          )
          .label;
      lastWinnerLabel = winnerLabel;
      lastPressOrderLabels = pressOrderLabels;
      notifyListeners();

      await _historyRepo.addResult(
        RoundResultModel(
          roundNumber: roundNumber,
          winnerGroupLabel: winnerLabel,
          timestamp: DateTime.now(),
          pressOrderLog: pressOrderLabels,
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
      String? wifiIp;
      String? fallbackIp;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.isEmpty || addr.isLoopback) continue;
          if (ip.startsWith('192.168.43.')) return ip;
          if (ip.startsWith('192.168.') && ip.endsWith('.1')) return ip;
          if (ip.startsWith('192.168.') && wifiIp == null) wifiIp = ip;
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
    _server.resetRound();
    lastWinnerLabel = null;
    lastPressOrderLabels = [];
    roundNumber++;
    groups = List<GroupModel>.from(_server.groups);
    notifyListeners();
  }

  List<RoundResultModel> getHistory() => _historyRepo.getAllResults();

  @override
  void dispose() {
    _server.stop().ignore();
    super.dispose();
  }
}
