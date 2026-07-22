import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../models/socket_message_model.dart';

class SocketClientService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _uuid = const Uuid();
  String? _serverIp;
  int _port = 4040;
  int _reconnectAttempt = 0;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isManuallyClosed = false;
  bool _hasConnectedSuccessfully = false;
  bool _isConnected = false;
  bool _isKicked = false;

  static const int _maxReconnectAttempts = 10;

  Function()? onWinner;
  Function()? onLose;
  Function()? onReset;
  Function(String reason)? onKicked;
  Function(bool connected)? onConnectionChanged;

  Future<bool> connect(
    String serverIp, {
    int port = 4040,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _serverIp = serverIp;
    _port = port;
    _isManuallyClosed = false;
    _isKicked = false;
    _hasConnectedSuccessfully = false;
    _isConnected = false;
    _reconnectAttempt = 0;
    await _attemptConnect();

    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < timeout) {
      if (_isConnected) return true;
      if (_isManuallyClosed) return false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    // Timeout habis — disconnect bersih
    disconnect();
    return false;
  }

  Future<void> _attemptConnect() async {
    // Cancel subscription lama agar tidak ada dua listener sekaligus
    await _subscription?.cancel();
    _subscription = null;

    try {
      final uri = Uri.parse('ws://$_serverIp:$_port');
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: false,
      );

      // Ping untuk memverifikasi koneksi berhasil
      _send(SocketMessage(
        type: MessageType.ping,
        senderId: 'self',
        sequenceId: _uuid.v4(),
      ));
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = SocketMessage.fromJson(
          jsonDecode(data as String) as Map<String, dynamic>);

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
          break;

        case MessageType.kicked:
          _isKicked = true;
          _isManuallyClosed = true; // stop auto-reconnect
          final reason = message.payload['reason'] as String? ??
              'Kamu dikeluarkan oleh Admin.';
          onKicked?.call(reason);
          _cleanupConnection();
          break;

        default:
          break;
      }
    } catch (_) {}
  }

  void sendPress() {
    _send(SocketMessage(
      type: MessageType.press,
      senderId: 'self',
      sequenceId: _uuid.v4(),
    ));
  }

  void sendReset() {
    _send(SocketMessage(
      type: MessageType.reset,
      senderId: 'self',
      sequenceId: _uuid.v4(),
    ));
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isConnected) {
        _send(SocketMessage(
          type: MessageType.ping,
          senderId: 'self',
          sequenceId: _uuid.v4(),
        ));
      }
    });
  }

  void _handleDisconnect() {
    if (_isKicked) return; // sudah di-handle oleh onKicked
    final wasConnected = _isConnected;
    _cleanupConnection();
    if (wasConnected) onConnectionChanged?.call(false);
    if (_isManuallyClosed) return;
    if (!_hasConnectedSuccessfully && !wasConnected) return;
    if (_reconnectAttempt >= _maxReconnectAttempts) return;

    final delaySeconds = (1 << _reconnectAttempt).clamp(1, 16);
    _reconnectAttempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isManuallyClosed && !_isKicked) _attemptConnect();
    });
  }

  void _cleanupConnection() {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
  }

  void _send(SocketMessage message) {
    try {
      _channel?.sink.add(jsonEncode(message.toJson()));
    } catch (_) {}
  }

  void disconnect() {
    _isManuallyClosed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _cleanupConnection();
  }
}
