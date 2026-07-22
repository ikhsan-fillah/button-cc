import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/socket_message_model.dart';
import '../models/group_model.dart';

/// Server berjalan di HP Admin. Semua koneksi client (4 grup) masuk ke sini.
/// Dart bersifat single-threaded event loop, sehingga request "press" yang
/// masuk lebih dulu otomatis diproses lebih dulu tanpa race condition (lihat
/// pembahasan sebelumnya).
class SocketServerService {
  HttpServer? _server;
  final Map<String, WebSocket> _clients = {};
  final Map<String, GroupModel> _groups = {};
  final _uuid = const Uuid();

  bool _locked = false;
  final List<String> _pressOrderLog = [];

  Function(List<GroupModel>)? onGroupsUpdated;
  Function(String winnerGroupId, List<String> pressOrder)? onRoundWinner;
  final Set<String> _processedSequenceIds = {};

  Future<void> start({int port = 4040}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleConnection);
  }

  void _handleConnection(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      final groupId = _uuid.v4();
      _clients[groupId] = socket;
      _groups[groupId] = GroupModel(
        id: groupId,
        label: 'Grup ${String.fromCharCode(65 + _groups.length)}', // A, B, C, D
        isConnected: true,
      );
      _broadcastGroupsUpdate();

      socket.listen(
        (data) => _handleMessage(groupId, data),
        onDone: () => _handleDisconnect(groupId),
        onError: (_) => _handleDisconnect(groupId),
      );
    }
  }

  void _handleMessage(String groupId, dynamic data) {
    final message = SocketMessage.fromJson(jsonDecode(data));

    // Cegah duplikasi pesan (misal akibat retry/reconnect)
    if (_processedSequenceIds.contains(message.sequenceId)) return;
    _processedSequenceIds.add(message.sequenceId);

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
  }

  /// Logic inti: check-and-set. Karena event loop Dart sekuensial, ini aman
  /// dari race condition walau 4 device kirim "press" hampir bersamaan.
  void _handlePress(String groupId) {
    _pressOrderLog.add(groupId);

    if (!_locked) {
      _locked = true;
      final label = _groups[groupId]?.label ?? groupId;

      onRoundWinner?.call(groupId, _pressOrderLog);

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
      // Grup ini terlambat, kirim balik status "sudah kalah"
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
    _clients[groupId]?.add(jsonEncode(message.toJson()));
  }

  List<GroupModel> get groups => _groups.values.toList();

  Future<void> stop() async {
    for (final socket in _clients.values) {
      await socket.close();
    }
    await _server?.close();
  }
}
