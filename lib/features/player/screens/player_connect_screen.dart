import 'package:flutter/material.dart';
import '../controller/player_controller.dart';
import 'player_buzzer_screen.dart';
import '../../../services/permission_service.dart';

class PlayerConnectScreen extends StatefulWidget {
  const PlayerConnectScreen({super.key});

  @override
  State<PlayerConnectScreen> createState() => _PlayerConnectScreenState();
}

class _PlayerConnectScreenState extends State<PlayerConnectScreen> {
  final TextEditingController _ipController = TextEditingController();
  final PlayerController _controller = PlayerController();
  bool _isConnecting = false;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _controller.init();
    // Minta permission SEKARANG saat layar dibuka,
    // jauh sebelum user tekan connect.
    // Dengan ini, saat WebSocket.connect() dipanggil
    // permission sudah pasti granted.
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final granted = await PermissionService.requestOnAppStart();
    if (mounted) setState(() => _permissionGranted = granted);
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
        const SnackBar(
            content: Text('Masukkan IP Address Admin terlebih dahulu!')),
      );
      return;
    }

    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Format IP tidak valid. Contoh: 192.168.43.1')),
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
            '\u2022 HP peserta terhubung ke hotspot Admin\n'
            '\u2022 App Admin sudah dijalankan sebagai Server\n'
            '\u2022 IP yang dimasukkan benar',
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
    // Tampilkan loading jika permission belum selesai diminta
    final permissionLoading =
        !_permissionGranted && !PermissionService.hasRequested;

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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'IP Address Admin',
                hintText: 'Contoh: 192.168.43.1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.router),
              ),
              onSubmitted: (_) {
                if (!_isConnecting && _permissionGranted) _connect();
              },
            ),
            const SizedBox(height: 16),
            // Tampilkan warning jika permission ditolak
            if (!_permissionGranted && PermissionService.hasRequested)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Izin jaringan lokal diperlukan. Buka Pengaturan → Izin Aplikasi untuk mengaktifkan.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ElevatedButton.icon(
              // Disable saat connecting ATAU saat permission belum selesai
              onPressed: (_isConnecting || permissionLoading)
                  ? null
                  : _connect,
              icon: (_isConnecting || permissionLoading)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link),
              label: Text(
                permissionLoading
                    ? 'Meminta izin jaringan...'
                    : (_isConnecting
                        ? 'Menghubungkan...'
                        : 'Connect ke Server'),
              ),
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
