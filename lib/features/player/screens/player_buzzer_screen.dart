import 'package:flutter/material.dart';
import '../controller/player_controller.dart';

class PlayerBuzzerScreen extends StatefulWidget {
  final PlayerController controller;
  const PlayerBuzzerScreen({super.key, required this.controller});

  @override
  State<PlayerBuzzerScreen> createState() => _PlayerBuzzerScreenState();
}

class _PlayerBuzzerScreenState extends State<PlayerBuzzerScreen> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) {
        setState(() {});
      }
    };
    widget.controller.addListener(_listener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  Color _getColor() {
    switch (widget.controller.status) {
      case PlayerRoundStatus.won:
        return Colors.green;
      case PlayerRoundStatus.lost:
        return Colors.grey;
      case PlayerRoundStatus.waiting:
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _getLabel() {
    switch (widget.controller.status) {
      case PlayerRoundStatus.won:
        return 'KAMU TERCEPAT!';
      case PlayerRoundStatus.lost:
        return 'KALAH CEPAT';
      case PlayerRoundStatus.waiting:
        return 'MENUNGGU...';
      default:
        return 'PENCET!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.controller.isConnected ? 'Terhubung' : 'Terputus'),
        backgroundColor: widget.controller.isConnected
            ? Colors.green
            : Colors.red,
      ),
      body: Center(
        child: GestureDetector(
          onTap: widget.controller.pressButton,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: _getColor(),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getLabel(),
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
