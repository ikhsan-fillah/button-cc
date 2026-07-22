import 'package:flutter/material.dart';
import '../controller/player_controller.dart';
import 'player_buzzer_screen.dart';

class PlayerConnectScreen extends StatefulWidget {
  const PlayerConnectScreen({super.key});

  @override
  State<PlayerConnectScreen> createState() => _PlayerConnectScreenState();
}

class _PlayerConnectScreenState extends State<PlayerConnectScreen> {
  final TextEditingController _ipController = TextEditingController();
  final PlayerController _controller = PlayerController();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk sebagai Grup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address Admin (contoh: 192.168.43.1)',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isConnecting
                  ? null
                  : () async {
                      setState(() {
                        _isConnecting = true;
                      });

                      final connected = await _controller.connectToServer(
                        _ipController.text.trim(),
                      );

                      if (!context.mounted) return;

                      if (!connected) {
                        setState(() {
                          _isConnecting = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Gagal terhubung ke server. Cek IP dan koneksi hotspot.',
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlayerBuzzerScreen(controller: _controller),
                        ),
                      );
                    },
              child: _isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
