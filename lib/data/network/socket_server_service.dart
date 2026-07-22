import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/socket_message_model.dart';
import '../models/group_model.dart';

/// Server berjalan di HP Admin. Semua koneksi client (peserta) masuk ke sini.
/// Dart bersifat single-threaded event loop, sehingga request "press" yang
/// masuk lebih dulu otomatis diproses lebih dulu tanpa race condition.
class SocketServerService {
  HttpServer? _server;
  final Map<String, WebSocket> _clients = {};
  final Map<String, GroupModel> _groups = {};
  final _uuid = const Uuid();

  bool _locked = false;
  final List<String> _pressOrderLog = [];
  final Set<String> _processedSequenceIds = {};

  Function(List<GroupModel>)? onGroupsUpdated;
  Function(String winnerGroupId, List<String> pressOrder)? onRoundWinner;

  Future<void> start({int port = 4040}) async {
    // Pastikan server lama sudah bersih sebelum start baru
    await stop();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleConnection);
  }

  void _handleConnection(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    final groupId = _uuid.v4();
    _clients[groupId] = socket;

    // Tentukan label: A, B, C, D... atau fallback angka jika > 26
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
      onDone: () => _handleDisconnect(groupId),
      onError: (_) => _handleDisconnect(groupId),
    );
  }

  void _handleMessage(String groupId, dynamic data) {
    try {
      final message = SocketMessage.fromJson(jsonDecode(data as String));

      // Cegah duplikasi pesan
      if (_processedSequenceIds.contains(message.sequenceId)) return;
      _processedSequenceIds.add(message.sequenceId);

      // Bersihkan set jika terlalu besar (memory guard)
      if (_processedSequenceIds.length > 1000) {
        _processedSequenceIds.clear();
      }

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
    } catch (_) {
      // Abaikan pesan malformed
    }
  }

  /// Logic inti: check-and-set. Karena event loop Dart sekuensial, ini aman
  /// dari race condition walau banyak device kirim "press" hampir bersamaan.
  void _handlePress(String groupId) {
    _pressOrderLog.add(groupId);

    if (!_locked) {
      _locked = true;
      final label = _groups[groupId]?.label ?? groupId;

      onRoundWinner?.call(groupId, List.from(_pressOrderLog));

      for (final entry in _clients.entries) {
        final isWinner = entry.key == groupId;
        _sendTo(
          entry.key,
          SocketMessage(
            type: MessageType.winnerBroadcast,
            senderId: 'server',
            sequenceId: _uuid.v4(),
            payload: {'isWinner': isWinner, 'winnerLabel': label},
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

  void resetRound() {
    _locked = false;
    _pressOrderLog.clear();
    _processedSequenceIds.clear();
    for (final id in _clients.keys) {
      _sendTo(
        id,
        SocketMessage(
          type: MessageType.reset,
          senderId: 'server',
          sequenceId: _uuid.v4(),
        ),
      );
    }
  }

  void renameGroup(String groupId, String newLabel) {
    if (_groups.containsKey(groupId)) {
      _groups[groupId] = _groups[groupId]!.copyWith(label: newLabel);
      _broadcastGroupsUpdate();
    }
  }

  void _handleDisconnect(String groupId) {
    _clients.remove(groupId);
    if (_groups.containsKey(groupId)) {
      _groups[groupId] = _groups[groupId]!.copyWith(isConnected: false);
    }
    _broadcastGroupsUpdate();
  }

  void _broadcastGroupsUpdate() {
    onGroupsUpdated?.call(_groups.values.toList());
  }

  void _sendTo(String groupId, SocketMessage message) {
    try {
      _clients[groupId]?.add(jsonEncode(message.toJson()));
    } catch (_) {}
  }

  List<GroupModel> get groups => _groups.values.toList();

  Future<void> stop() async {
    for (final socket in _clients.values) {
      try {
        await socket.close();
      } catch (_) {}
    }
    _clients.clear();
    _groups.clear();
    _locked = false;
    _pressOrderLog.clear();
    _processedSequenceIds.clear();
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
  }
}
