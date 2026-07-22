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

      // Tangani kicked TERPISAH dari setState menggunakan postFrameCallback
      // agar tidak konflik dengan rebuild widget yang sedang berlangsung.
      if (widget.controller.kickedReason != null && !_kickedHandled) {
        _kickedHandled = true;
        // setState dulu agar UI langsung berubah ke layar merah "Dikeluarkan"
        setState(() {});
        // Baru jadwalkan dialog setelah frame selesai dirender
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showKickedDialog(widget.controller.kickedReason!);
        });
        return; // jangan setState dua kali
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
                MaterialPageRoute(
                  builder: (_) => const PlayerConnectScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Warna tombol buzzer ────────────────────────────────────────────────────
  Color _bgColor() {
    if (widget.controller.kickedReason != null) return Colors.red.shade900;
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

  // ── Label tombol buzzer ────────────────────────────────────────────────────
  String _label() {
    if (widget.controller.kickedReason != null) {
      return '🚫 DIKELUARKAN\noleh Admin';
    }
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
      widget.controller.kickedReason == null &&
      widget.controller.status == PlayerRoundStatus.idle;

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isKicked = widget.controller.kickedReason != null;

    return Scaffold(
      backgroundColor: isKicked ? Colors.red.shade50 : Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isKicked
            ? Colors.red.shade800
            : (widget.controller.isConnected ? null : Colors.grey.shade700),
        title: Row(
          children: [
            Icon(
              isKicked
                  ? Icons.person_off
                  : (widget.controller.isConnected
                      ? Icons.wifi
                      : Icons.wifi_off),
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
                    : (widget.controller.isConnected
                        ? Colors.green
                        : Colors.red),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: isKicked
            // ── Layar Kicked ─────────────────────────────────────────────────
            ? Column(
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
                          builder: (_) => const PlayerConnectScreen(),
                        ),
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
              )
            // ── Layar Buzzer Normal ───────────────────────────────────────────
            : GestureDetector(
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
