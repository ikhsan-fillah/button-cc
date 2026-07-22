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

  Future<void> _connect() async {
    final ip = _ipController.text.trim();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan IP Address Admin terlebih dahulu!')),
      );
      return;
    }

    // Validasi format IP sederhana
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format IP tidak valid. Contoh: 192.168.43.1')),
      );
      return;
    }

    setState(() => _isConnecting = true);

    final connected = await _controller.connectToServer(ip);

    if (!context.mounted) return;

    if (!connected) {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal terhubung ke $ip\n'
            'Pastikan:\n'
            '• HP peserta terhubung ke hotspot Admin\n'
            '• App Admin sudah dijalankan sebagai Server\n'
            '• IP yang dimasukkan benar',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerBuzzerScreen(controller: _controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk sebagai Peserta')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.wifi, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Hubungkan HP ini ke hotspot HP Admin,\nlalu masukkan IP yang ditampilkan di layar Admin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _ipController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'IP Address Admin',
                hintText: 'Contoh: 192.168.43.1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.router),
              ),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _connect,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link),
              label: Text(_isConnecting ? 'Menghubungkan...' : 'Connect ke Server'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            if (_isConnecting) ...
              [
                const SizedBox(height: 12),
                const Text(
                  'Sedang mencoba terhubung (maks. 10 detik)...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
