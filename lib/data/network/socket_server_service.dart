import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/socket_message_model.dart';
import '../models/group_model.dart';

/// Server berjalan di HP Admin.
/// Dart single-threaded event loop → press pertama selalu diproses pertama,
/// tidak ada race condition.
class SocketServerService {
  HttpServer? _server;
  final Map<String, WebSocket> _clients = {};
  final Map<String, GroupModel> _groups = {};
  final _uuid = const Uuid();

  bool _locked = false;
  final List<String> _pressOrderLog = [];
  final Set<String> _processedSequenceIds = {};
  bool _isStopping = false;

  Function(List<GroupModel>)? onGroupsUpdated;
  Function(String winnerGroupId, List<String> pressOrder)? onRoundWinner;

  Future<void> start({int port = 4040}) async {
    // Bersihkan state sebelumnya TANPA menutup server lama
    // (server lama sudah di-close oleh stop() sebelumnya)
    _clients.clear();
    _groups.clear();
    _locked = false;
    _pressOrderLog.clear();
    _processedSequenceIds.clear();
    _isStopping = false;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleConnection);
  }

  void _handleConnection(HttpRequest request) async {
    // Tolak koneksi baru jika sedang stopping
    if (_isStopping) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..close();
      return;
    }

    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    final groupId = _uuid.v4();
    _clients[groupId] = socket;

    final idx = _groups.length;
    final label = idx < 26
        ? 'Grup ${String.fromCharCode(65 + idx)}'
        : 'Grup ${idx + 1}';

    _groups[groupId] = GroupModel(
      id: groupId,
      label: label,
      isConnected: true,
    );
    _broadcastGroupsUpdate();

    socket.listen(
      (data) => _handleMessage(groupId, data),
      onDone: () => _onClientGone(groupId),
      onError: (_) => _onClientGone(groupId),
      cancelOnError: false,
    );
  }

  void _handleMessage(String groupId, dynamic data) {
    try {
      final message = SocketMessage.fromJson(
          jsonDecode(data as String) as Map<String, dynamic>);

      if (_processedSequenceIds.contains(message.sequenceId)) return;
      _processedSequenceIds.add(message.sequenceId);
      if (_processedSequenceIds.length > 2000) _processedSequenceIds.clear();

      switch (message.type) {
        case MessageType.press:
          _handlePress(groupId);
          break;
        case MessageType.ping:
          _sendTo(
            groupId,
            SocketMessage(
              type: MessageType.pong,
              senderId: 'server',
              sequenceId: _uuid.v4(),
            ),
          );
          break;
        case MessageType.reset:
          resetRound();
          break;
        default:
          break;
      }
    } catch (_) {}
  }

  void _handlePress(String groupId) {
    if (!_clients.containsKey(groupId)) return;
    _pressOrderLog.add(groupId);

    if (!_locked) {
      _locked = true;
      final label = _groups[groupId]?.label ?? groupId;
      onRoundWinner?.call(groupId, List<String>.from(_pressOrderLog));

      for (final entry in _clients.entries) {
        _sendTo(
          entry.key,
          SocketMessage(
            type: MessageType.winnerBroadcast,
            senderId: 'server',
            sequenceId: _uuid.v4(),
            payload: {
              'isWinner': entry.key == groupId,
              'winnerLabel': label,
            },
          ),
        );
      }
    } else {
      _sendTo(
        groupId,
        SocketMessage(
          type: MessageType.ack,
          senderId: 'server',
          sequenceId: _uuid.v4(),
          payload: {'status': 'too_late'},
        ),
      );
    }
  }

  // Dipanggil ketika koneksi putus secara alami (bukan di-kick)
  void _onClientGone(String groupId) {
    if (_isStopping) return;
    _clients.remove(groupId);
    if (_groups.containsKey(groupId)) {
      _groups[groupId] = _groups[groupId]!.copyWith(isConnected: false);
    }
    _broadcastGroupsUpdate();
  }

  /// Kick (hapus) peserta dari admin. Kirim pesan kicked lalu putus koneksi.
  Future<void> kickGroup(String groupId) async {
    _sendTo(
      groupId,
      SocketMessage(
        type: MessageType.kicked,
        senderId: 'server',
        sequenceId: _uuid.v4(),
        payload: {'reason': 'Kamu dikeluarkan oleh Admin.'},
      ),
    );
    // Beri sedikit waktu agar pesan terkirim sebelum socket ditutup
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      await _clients[groupId]?.close(1000, 'kicked');
    } catch (_) {}
    _clients.remove(groupId);
    _groups.remove(groupId);
    _broadcastGroupsUpdate();
  }

  void resetRound() {
    _locked = false;
    _pressOrderLog.clear();
    // Jangan clear _processedSequenceIds di sini agar tidak memicu bug timing
    final resetMsg = SocketMessage(
      type: MessageType.reset,
      senderId: 'server',
      sequenceId: _uuid.v4(),
    );
    // Kirim ke semua client yang masih terhubung
    for (final id in List<String>.from(_clients.keys)) {
      _sendTo(id, resetMsg);
    }
    _broadcastGroupsUpdate();
  }

  void renameGroup(String groupId, String newLabel) {
    if (_groups.containsKey(groupId)) {
      _groups[groupId] = _groups[groupId]!.copyWith(label: newLabel);
      _broadcastGroupsUpdate();
    }
  }

  void _broadcastGroupsUpdate() {
    onGroupsUpdated?.call(List<GroupModel>.from(_groups.values));
  }

  void _sendTo(String groupId, SocketMessage message) {
    try {
      final socket = _clients[groupId];
      if (socket != null && socket.readyState == WebSocket.open) {
        socket.add(jsonEncode(message.toJson()));
      }
    } catch (_) {}
  }

  List<GroupModel> get groups => List<GroupModel>.from(_groups.values);

  Future<void> stop() async {
    _isStopping = true;
    for (final socket in _clients.values) {
      try {
        await socket.close(1001, 'server_stop');
      } catch (_) {}
    }
    _clients.clear();
    _groups.clear();
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _locked = false;
    _pressOrderLog.clear();
    _processedSequenceIds.clear();
    _isStopping = false;
  }
}
