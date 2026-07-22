import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/socket_message_model.dart';
import '../models/group_model.dart';

/// Server berjalan di HP Admin (Android).
/// Catatan platform: dart:io HttpServer.bind() hanya berjalan di Android.
/// iOS sandbox melarang app membuka raw TCP server — role Admin harus Android.
class SocketServerService {
  HttpServer? _server;
  final Map<String, WebSocket> _clients = {};
  final Map<String, GroupModel> _groups = {};
  final _uuid = const Uuid();

  // Menggunakan mutex flag sederhana untuk melindungi race condition press/reset.
  // Dart single-threaded event loop memastikan tidak ada true concurrency,
  // tapi microtask boundary tetap bisa menyebabkan interleaving.
  bool _locked = false;
  bool _isStopping = false;

  // Digunakan untuk deduplication pesan
  final Set<String> _processedSequenceIds = {};

  // Press log per ronde — hanya dimodifikasi saat _roundLock dipegang
  final List<String> _pressOrderLog = [];

  Function(List<GroupModel>)? onGroupsUpdated;
  Function(String winnerGroupId, List<String> pressOrder)? onRoundWinner;

  Future<void> start({int port = 4040}) async {
    _isStopping = false;
    _clients.clear();
    _groups.clear();
    _resetRoundState();

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleConnection);
  }

  void _handleConnection(HttpRequest request) async {
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
    final label =
        idx < 26 ? 'Grup ${String.fromCharCode(65 + idx)}' : 'Grup ${idx + 1}';

    _groups[groupId] = GroupModel(id: groupId, label: label, isConnected: true);
    _broadcastGroupsUpdate();

    socket.listen(
      (data) => _handleMessage(groupId, data),
      onDone: () => _onClientGone(groupId),
      onError: (_) => _onClientGone(groupId),
      cancelOnError: false,
    );
  }

  void _handleMessage(String groupId, dynamic data) {
    if (_isStopping) return;
    try {
      final message = SocketMessage.fromJson(
          jsonDecode(data as String) as Map<String, dynamic>);

      // Deduplication
      if (message.sequenceId.isNotEmpty) {
        if (_processedSequenceIds.contains(message.sequenceId)) return;
        _processedSequenceIds.add(message.sequenceId);
        if (_processedSequenceIds.length > 2000) _processedSequenceIds.clear();
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
    } catch (_) {}
  }

  void _handlePress(String groupId) {
    if (!_clients.containsKey(groupId)) return;
    if (_isStopping) return;

    // Snapshot _locked sebelum apapun untuk atomicity di event loop Dart
    final wasLocked = _locked;
    _pressOrderLog.add(groupId);

    if (!wasLocked) {
      _locked = true; // set segera agar press berikutnya masuk else branch
      final label = _groups[groupId]?.label ?? groupId;
      // Snapshot pressOrderLog untuk dikirim ke callback
      final snapshot = List<String>.from(_pressOrderLog);

      onRoundWinner?.call(groupId, snapshot);

      for (final entry in List<MapEntry<String, WebSocket>>.from(
          _clients.entries)) {
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

  void resetRound() {
    // Reset state ronde secara atomik
    _resetRoundState();

    // Broadcast reset ke semua client yang masih terhubung
    final msg = SocketMessage(
      type: MessageType.reset,
      senderId: 'server',
      sequenceId: _uuid.v4(),
    );
    for (final id in List<String>.from(_clients.keys)) {
      _sendTo(id, msg);
    }
    _broadcastGroupsUpdate();
  }

  void _resetRoundState() {
    _locked = false;
    _pressOrderLog.clear();
    // Tidak clear _processedSequenceIds di sini agar deduplication tetap jalan
  }

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
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      await _clients[groupId]?.close(1000, 'kicked');
    } catch (_) {}
    _clients.remove(groupId);
    _groups.remove(groupId);
    _broadcastGroupsUpdate();
  }

  void renameGroup(String groupId, String newLabel) {
    if (_groups.containsKey(groupId)) {
      _groups[groupId] = _groups[groupId]!.copyWith(label: newLabel);
      _broadcastGroupsUpdate();
    }
  }

  void _onClientGone(String groupId) {
    if (_isStopping) return;
    _clients.remove(groupId);
    if (_groups.containsKey(groupId)) {
      _groups[groupId] = _groups[groupId]!.copyWith(isConnected: false);
    }
    _broadcastGroupsUpdate();
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
    // Salin keys agar tidak ConcurrentModificationError
    final clientIds = List<String>.from(_clients.keys);
    for (final id in clientIds) {
      try {
        await _clients[id]?.close(1001, 'server_stop');
      } catch (_) {}
    }
    _clients.clear();
    _groups.clear();
    _resetRoundState();
    _processedSequenceIds.clear();
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _isStopping = false;
  }
}
