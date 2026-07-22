import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../models/socket_message_model.dart';

/// Client berjalan di 4 HP Player/Grup. Terhubung ke server (HP Admin)
/// lewat hotspot lokal. Dilengkapi heartbeat + auto-reconnect dengan
/// exponential backoff (lihat pembahasan sebelumnya soal koneksi terputus).
class SocketClientService {
  WebSocketChannel? _channel;
  final _uuid = const Uuid();
  String? _serverIp;
  int _port = 4040;
  int _reconnectAttempt = 0;
  Timer? _heartbeatTimer;
  bool _isManuallyClosed = false;
  bool _hasConnectedSuccessfully = false;
  bool _isConnected = false;

  Function()? onWinner;
  Function()? onLose;
  Function()? onReset;
  Function(bool connected)? onConnectionChanged;

  Future<bool> connect(
    String serverIp, {
    int port = 4040,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _serverIp = serverIp;
    _port = port;
    _isManuallyClosed = false;
    _hasConnectedSuccessfully = false;
    _isConnected = false;
    _reconnectAttempt = 0;
    await _attemptConnect();

    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < timeout) {
      if (_isConnected) return true;
      if (_isManuallyClosed) return false;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    disconnect();
    return false;
  }

  Future<void> _attemptConnect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$_serverIp:$_port'));

      _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );

      _send(
        SocketMessage(
          type: MessageType.ping,
          senderId: 'self',
          sequenceId: _uuid.v4(),
        ),
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic data) {
    final message = SocketMessage.fromJson(jsonDecode(data));
    switch (message.type) {
      case MessageType.winnerBroadcast:
        final isWinner = message.payload['isWinner'] == true;
        isWinner ? onWinner?.call() : onLose?.call();
        break;
      case MessageType.reset:
        onReset?.call();
        break;
      case MessageType.pong:
        if (!_isConnected) {
          _isConnected = true;
          _hasConnectedSuccessfully = true;
          _reconnectAttempt = 0;
          onConnectionChanged?.call(true);
          _startHeartbeat();
        }
        break; // heartbeat OK
      default:
        break;
    }
  }

  void sendPress() {
    _send(
      SocketMessage(
        type: MessageType.press,
        senderId: 'self',
        sequenceId: _uuid.v4(),
      ),
    );
  }

  void sendReset() {
    _send(
      SocketMessage(
        type: MessageType.reset,
        senderId: 'self',
        sequenceId: _uuid.v4(),
      ),
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _send(
        SocketMessage(
          type: MessageType.ping,
          senderId: 'self',
          sequenceId: _uuid.v4(),
        ),
      );
    });
  }

  void _handleDisconnect() {
    final wasConnected = _isConnected;
    _isConnected = false;
    onConnectionChanged?.call(false);
    _heartbeatTimer?.cancel();
    if (_isManuallyClosed) return;

    if (!_hasConnectedSuccessfully && !wasConnected) {
      return;
    }

    // Exponential backoff: 1s, 2s, 4s, 8s... maksimal 16s
    final delaySeconds = (1 << _reconnectAttempt).clamp(1, 16);
    _reconnectAttempt++;
    Timer(Duration(seconds: delaySeconds), () {
      if (!_isManuallyClosed) _attemptConnect();
    });
  }

  void _send(SocketMessage message) {
    _channel?.sink.add(jsonEncode(message.toJson()));
  }

  void disconnect() {
    _isManuallyClosed = true;
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
  }
}
