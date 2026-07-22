import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/socket_message_model.dart';

/// Client WebSocket menggunakan dart:io WebSocket langsung.
/// Lebih reliable daripada web_socket_channel di Android karena:
/// - Tidak ada layer abstraksi yang bisa fail
/// - connect() adalah Future yang resolve tepat saat handshake selesai
/// - Tidak ada channel.ready yang flaky
class SocketClientService {
  WebSocket? _socket;
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
  Function(String winnerLabel, List<String> pressOrderLabels, int? myPosition)?
      onWinnerBroadcast;

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
    disconnect();
    return false;
  }

  Future<void> _attemptConnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _heartbeatTimer?.cancel();
    try {
      await _socket?.close(1001, 'reconnecting');
    } catch (_) {}
    _socket = null;

    if (_isManuallyClosed || _isKicked) return;

    try {
      // dart:io WebSocket.connect() resolve TEPAT saat handshake selesai.
      // Tidak ada race condition, tidak ada channel.ready yang flaky.
      final ws = await WebSocket.connect(
        'ws://$_serverIp:$_port',
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('WebSocket connect timeout'),
      );

      if (_isManuallyClosed || _isKicked) {
        await ws.close(1001, 'cancelled');
        return;
      }

      _socket = ws;

      // Pasang listener SEGERA setelah connect selesai
      // Server akan kirim pong welcome, kita tinggal terima
      _subscription = ws.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: false,
      );
    } on TimeoutException {
      _scheduleReconnect();
    } on Exception {
      _scheduleReconnect();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = SocketMessage.fromJson(
          jsonDecode(data as String) as Map<String, dynamic>);

      switch (message.type) {
        case MessageType.pong:
          // Terima pong welcome dari server = koneksi confirmed
          if (!_isConnected) {
            _isConnected = true;
            _hasConnectedSuccessfully = true;
            _reconnectAttempt = 0;
            onConnectionChanged?.call(true);
            _startHeartbeat();
          }
          break;

        case MessageType.winnerBroadcast:
          final isWinner = message.payload['isWinner'] == true;
          final winnerLabel =
              message.payload['winnerLabel'] as String? ?? '';
          final rawOrder = message.payload['pressOrderLabels'];
          final pressOrderLabels = rawOrder is List
              ? List<String>.from(rawOrder.map((e) => e.toString()))
              : <String>[];
          final myPosition = message.payload['myPosition'] as int?;
          onWinnerBroadcast?.call(winnerLabel, pressOrderLabels, myPosition);
          isWinner ? onWinner?.call() : onLose?.call();
          break;

        case MessageType.reset:
          onReset?.call();
          break;

        case MessageType.kicked:
          _isKicked = true;
          _isManuallyClosed = true;
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
        Timer.periodic(const Duration(seconds: 10), (_) {
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
    if (_isKicked) return;
    final wasConnected = _isConnected;
    _cleanupConnection();
    if (wasConnected) onConnectionChanged?.call(false);
    if (_isManuallyClosed) return;
    if (!_hasConnectedSuccessfully && !wasConnected) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isManuallyClosed || _isKicked) return;
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
      _socket?.close(1000, 'cleanup');
    } catch (_) {}
    _socket = null;
  }

  void _send(SocketMessage message) {
    try {
      if (_socket != null &&
          _socket!.readyState == WebSocket.open) {
        _socket!.add(jsonEncode(message.toJson()));
      }
    } catch (_) {}
  }

  void disconnect() {
    _isManuallyClosed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _cleanupConnection();
  }
}
