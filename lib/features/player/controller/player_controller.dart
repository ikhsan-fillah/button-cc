import 'package:flutter/foundation.dart';
import '../../../data/network/socket_client_service.dart';
import '../../../services/audio_service.dart';
import '../../../services/permission_service.dart';

enum PlayerRoundStatus { idle, waiting, won, lost }

class PlayerController extends ChangeNotifier {
  final SocketClientService _client = SocketClientService();
  final AudioService _audio = AudioService();

  bool isConnected = false;
  PlayerRoundStatus status = PlayerRoundStatus.idle;
  String? kickedReason;

  Future<void> init() async {
    await _audio.init();
  }

  Future<bool> connectToServer(String serverIp) async {
    await PermissionService.requestLocalNetworkPermission();

    _client.onConnectionChanged = (connected) {
      isConnected = connected;
      if (!connected && kickedReason == null) {
        // Reset status saat koneksi putus (bukan kicked)
        status = PlayerRoundStatus.idle;
      }
      notifyListeners();
    };

    _client.onWinner = () async {
      status = PlayerRoundStatus.won;
      await _audio.playBuzzer();
      notifyListeners();
    };

    _client.onLose = () {
      status = PlayerRoundStatus.lost;
      notifyListeners();
    };

    _client.onReset = () {
      status = PlayerRoundStatus.idle;
      notifyListeners();
    };

    _client.onKicked = (reason) {
      kickedReason = reason;
      isConnected = false;
      notifyListeners();
    };

    return _client.connect(serverIp);
  }

  void pressButton() {
    // Hanya bisa pencet jika terhubung dan status idle
    if (!isConnected) return;
    if (status != PlayerRoundStatus.idle) return;
    status = PlayerRoundStatus.waiting;
    notifyListeners();
    _client.sendPress();
  }

  @override
  void dispose() {
    _client.disconnect();
    _audio.dispose();
    super.dispose();
  }
}
