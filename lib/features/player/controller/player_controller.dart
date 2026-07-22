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

  // Info urutan pencetan — diisi saat winnerBroadcast diterima
  String winnerLabel = '';
  List<String> pressOrderLabels = [];
  int? myPosition; // posisi saya (1 = tercepat), null = belum pencet

  Future<void> init() async {
    await _audio.init();
  }

  Future<bool> connectToServer(String serverIp) async {
    kickedReason = null;
    isConnected = false;
    status = PlayerRoundStatus.idle;
    winnerLabel = '';
    pressOrderLabels = [];
    myPosition = null;

    await PermissionService.requestLocalNetworkPermission();

    _client.onConnectionChanged = (connected) {
      isConnected = connected;
      if (!connected && kickedReason == null) {
        status = PlayerRoundStatus.idle;
      }
      notifyListeners();
    };

    // Callback lengkap dengan urutan pencetan
    _client.onWinnerBroadcast = (label, orderLabels, pos) {
      winnerLabel = label;
      pressOrderLabels = orderLabels;
      myPosition = pos;
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
      winnerLabel = '';
      pressOrderLabels = [];
      myPosition = null;
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
