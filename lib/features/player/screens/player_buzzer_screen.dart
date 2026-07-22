import 'package:flutter/material.dart';
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
      // Jika di-kick oleh admin, tampilkan dialog lalu kembali ke connect screen
      if (widget.controller.kickedReason != null && !_kickedHandled) {
        _kickedHandled = true;
        _showKickedDialog(widget.controller.kickedReason!);
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
              Navigator.pop(context); // tutup dialog
              // Kembali ke layar connect dan hapus semua history
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const PlayerConnectScreen()),
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
    if (!widget.controller.isConnected) return Colors.grey.shade600;
    switch (widget.controller.status) {
      case PlayerRoundStatus.won:
        return Colors.green.shade600;
      case PlayerRoundStatus.lost:
        return Colors.grey.shade400;
      case PlayerRoundStatus.waiting:
        return Colors.orange.shade600;
      default:
        return Colors.red.shade600;
    }
  }

  String _label() {
    if (!widget.controller.isConnected) return 'TERPUTUS\nMenghubungkan ulang...';
    switch (widget.controller.status) {
      case PlayerRoundStatus.won:
        return '🏆 KAMU TERCEPAT!';
      case PlayerRoundStatus.lost:
        return '❌ TERLAMBAT';
      case PlayerRoundStatus.waiting:
        return '⏳ MENUNGGU...';
      default:
        return 'PENCET!';
    }
  }

  bool _canPress() =>
      widget.controller.isConnected &&
      widget.controller.status == PlayerRoundStatus.idle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(
              widget.controller.isConnected
                  ? Icons.wifi
                  : Icons.wifi_off,
              size: 18,
              color: widget.controller.isConnected
                  ? Colors.green
                  : Colors.red,
            ),
            const SizedBox(width: 6),
            Text(
              widget.controller.isConnected ? 'Terhubung' : 'Terputus',
              style: TextStyle(
                color: widget.controller.isConnected
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Center(
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
    );
  }
}
