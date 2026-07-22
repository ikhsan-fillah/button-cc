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

  Future<void> init() async {
    await _audio.init();
  }

  Future<bool> connectToServer(String serverIp) async {
    await PermissionService.requestLocalNetworkPermission();

    _client.onConnectionChanged = (connected) {
      isConnected = connected;
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

    return _client.connect(serverIp);
  }

  void pressButton() {
    if (status != PlayerRoundStatus.idle) return; // cegah double press
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
