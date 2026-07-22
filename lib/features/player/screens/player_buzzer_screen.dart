import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../controller/player_controller.dart';
import 'player_connect_screen.dart';

class PlayerBuzzerScreen extends StatefulWidget {
  final PlayerController controller;
  const PlayerBuzzerScreen({super.key, required this.controller});

  @override
  State<PlayerBuzzerScreen> createState() => _PlayerBuzzerScreenState();
}

class _PlayerBuzzerScreenState extends State<PlayerBuzzerScreen> {
  late final VoidCallback _listener;
  bool _kickedHandled = false;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (!mounted) return;
      if (widget.controller.kickedReason != null && !_kickedHandled) {
        _kickedHandled = true;
        setState(() {});
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showKickedDialog(widget.controller.kickedReason!);
        });
        return;
      }
      setState(() {});
    };
    widget.controller.addListener(_listener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  void _showKickedDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Dikeluarkan dari Sesi'),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const PlayerConnectScreen()),
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _bgColor() {
    if (widget.controller.kickedReason != null) return Colors.red.shade900;
    if (!widget.controller.isConnected) return Colors.grey.shade600;
    switch (widget.controller.status) {
      case PlayerRoundStatus.won:
        return Colors.green.shade600;
      case PlayerRoundStatus.lost:
        return Colors.red.shade300;
      case PlayerRoundStatus.waiting:
        return Colors.orange.shade600;
      default:
        return Colors.red.shade600;
    }
  }

  String _label() {
    if (widget.controller.kickedReason != null) return '🚫 DIKELUARKAN\noleh Admin';
    if (!widget.controller.isConnected) return 'TERPUTUS\nMenghubungkan ulang...';
    switch (widget.controller.status) {
      case PlayerRoundStatus.won:
        return '🏆 KAMU TERCEPAT!';
      case PlayerRoundStatus.lost:
        final pos = widget.controller.myPosition;
        return pos != null ? '❌ TERLAMBAT\nUrutan ke-$pos' : '❌ TERLAMBAT';
      case PlayerRoundStatus.waiting:
        return '⏳ MENUNGGU...';
      default:
        return 'PENCET!';
    }
  }

  bool _canPress() =>
      widget.controller.isConnected &&
      widget.controller.kickedReason == null &&
      widget.controller.status == PlayerRoundStatus.idle;

  // Widget urutan pencetan — ditampilkan di bawah tombol saat ronde selesai
  Widget _buildPressOrder() {
    final order = widget.controller.pressOrderLabels;
    final status = widget.controller.status;
    if (order.isEmpty) return const SizedBox.shrink();
    if (status != PlayerRoundStatus.won && status != PlayerRoundStatus.lost) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 24, left: 24, right: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Urutan Pencetan Ronde Ini:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...order.asMap().entries.map((e) {
            final no = e.key + 1;
            final label = e.value;
            final isMe = no == widget.controller.myPosition;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: no == 1
                        ? Colors.green
                        : (isMe ? Colors.orange : Colors.grey.shade300),
                    child: Text(
                      '$no',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: no == 1 || isMe ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label + (isMe ? '  ← Kamu' : '') + (no == 1 ? '  🏆' : ''),
                    style: TextStyle(
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      color: no == 1 ? Colors.green.shade700 : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKicked = widget.controller.kickedReason != null;

    return Scaffold(
      backgroundColor: isKicked ? Colors.red.shade50 : Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isKicked ? Colors.red.shade800 : null,
        title: Row(
          children: [
            Icon(
              isKicked
                  ? Icons.person_off
                  : (widget.controller.isConnected ? Icons.wifi : Icons.wifi_off),
              size: 18,
              color: isKicked
                  ? Colors.white
                  : (widget.controller.isConnected ? Colors.green : Colors.red),
            ),
            const SizedBox(width: 6),
            Text(
              isKicked
                  ? 'Dikeluarkan oleh Admin'
                  : (widget.controller.isConnected ? 'Terhubung' : 'Terputus'),
              style: TextStyle(
                color: isKicked
                    ? Colors.white
                    : (widget.controller.isConnected ? Colors.green : Colors.red),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: isKicked
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Kamu Dikeluarkan',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.controller.kickedReason!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const PlayerConnectScreen()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Kembali & Connect Ulang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Center(
                    child: GestureDetector(
                      onTap: _canPress() ? widget.controller.pressButton : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          color: _bgColor(),
                          shape: BoxShape.circle,
                          boxShadow: _canPress()
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.5),
                                    blurRadius: 30,
                                    spreadRadius: 8,
                                  )
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            _label(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildPressOrder(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
