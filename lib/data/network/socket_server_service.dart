import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/socket_message_model.dart';
import '../models/group_model.dart';

class SocketServerService {
  HttpServer? _server;
  final Map<String, WebSocket> _clients = {};
  final Map<String, GroupModel> _groups = {};
  final _uuid = const Uuid();

  bool _locked = false;
  bool _isStopping = false;
  final Set<String> _processedSequenceIds = {};
  final List<String> _pressOrderLog = [];

  Function(List<GroupModel>)? onGroupsUpdated;
  Function(String winnerGroupId, List<String> pressOrderLabels)? onRoundWinner;

  Future<void> start({int port = 4040}) async {
    _isStopping = false;
    _clients.clear();
    _groups.clear();
    _resetRoundState();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('[SERVER] Listening on port $port');
    _server!.listen(_handleConnection);
  }

  void _handleConnection(HttpRequest request) async {
    print('[SERVER] Incoming connection from ${request.connectionInfo?.remoteAddress.address}');

    if (_isStopping) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..close();
      return;
    }
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      print('[SERVER] Not a WebSocket upgrade request — rejected');
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    WebSocket socket;
    try {
      socket = await WebSocketTransformer.upgrade(request);
      print('[SERVER] WebSocket upgrade OK, readyState=${socket.readyState}');
    } catch (e) {
      print('[SERVER] WebSocket upgrade FAILED: $e');
      return;
    }

    if (_isStopping) {
      await socket.close(1001, 'server_stopping');
      return;
    }

    final groupId = _uuid.v4();
    _clients[groupId] = socket;

    final idx = _groups.length;
    final label =
        idx < 26 ? 'Grup ${String.fromCharCode(65 + idx)}' : 'Grup ${idx + 1}';
    _groups[groupId] = GroupModel(id: groupId, label: label, isConnected: true);
    print('[SERVER] Registered $label (id=$groupId)');

    socket.listen(
      (data) => _handleMessage(groupId, data),
      onDone: () {
        print('[SERVER] onDone for $label — socket closed by remote or OS');
        _onClientGone(groupId);
      },
      onError: (e) {
        print('[SERVER] onError for $label: $e');
        _onClientGone(groupId);
      },
      cancelOnError: false,
    );

    // Tunda 100ms sebelum kirim pong welcome.
    // Beberapa Android: readyState masih CONNECTING tepat setelah upgrade(),
    // socket.add() langsung throw StateError -> onDone terpanggil -> disconnect.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    print('[SERVER] Sending welcome pong to $label, readyState=${socket.readyState}');
    _sendTo(
      groupId,
      SocketMessage(
        type: MessageType.pong,
        senderId: 'server',
        sequenceId: _uuid.v4(),
        payload: {'welcome': true, 'label': label},
      ),
    );

    _broadcastGroupsUpdate();
  }

  void _handleMessage(String groupId, dynamic data) {
    if (_isStopping) return;
    try {
      final message = SocketMessage.fromJson(
          jsonDecode(data as String) as Map<String, dynamic>);

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
    } catch (e) {
      print('[SERVER] _handleMessage error: $e');
    }
  }

  void _handlePress(String groupId) {
    if (!_clients.containsKey(groupId)) return;
    if (_isStopping) return;

    final wasLocked = _locked;
    _pressOrderLog.add(groupId);
    final myPosition = _pressOrderLog.length;

    if (!wasLocked) {
      _locked = true;
      final winnerLabel = _groups[groupId]?.label ?? groupId;
      final pressOrderLabels = _pressOrderLog
          .map((id) => _groups[id]?.label ?? id)
          .toList();

      onRoundWinner?.call(groupId, pressOrderLabels);

      for (final entry
          in List<MapEntry<String, WebSocket>>.from(_clients.entries)) {
        final isWinner = entry.key == groupId;
        final pos = _pressOrderLog.indexOf(entry.key) + 1;
        _sendTo(
          entry.key,
          SocketMessage(
            type: MessageType.winnerBroadcast,
            senderId: 'server',
            sequenceId: _uuid.v4(),
            payload: {
              'isWinner': isWinner,
              'winnerLabel': winnerLabel,
              'pressOrderLabels': pressOrderLabels,
              'myPosition': pos > 0 ? pos : null,
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
          payload: {
            'status': 'too_late',
            'myPosition': myPosition,
          },
        ),
      );
    }
  }

  void resetRound() {
    _resetRoundState();
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
    final label = _groups[groupId]?.label ?? groupId;
    print('[SERVER] _onClientGone: $label removed from active clients');
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
      if (socket == null) {
        print('[SERVER] _sendTo: socket null for $groupId');
        return;
      }
      print('[SERVER] _sendTo ${_groups[groupId]?.label}: readyState=${socket.readyState}, type=${message.type.name}');
      if (socket.readyState == WebSocket.open) {
        socket.add(jsonEncode(message.toJson()));
      } else {
        print('[SERVER] _sendTo SKIP: socket not open (state=${socket.readyState})');
      }
    } catch (e) {
      print('[SERVER] _sendTo ERROR: $e');
    }
  }

  List<GroupModel> get groups => List<GroupModel>.from(_groups.values);

  Future<void> stop() async {
    _isStopping = true;
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
    print('[SERVER] Stopped.');
  }
}
