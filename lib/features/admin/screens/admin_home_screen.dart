import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/admin_controller.dart';
import 'admin_history_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final AdminController _controller = AdminController();
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _controller.startServer();
    _listener = () {
      if (mounted) setState(() {});
    };
    _controller.addListener(_listener);
  }

  @override
  void dispose() {
    _controller.removeListener(_listener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AdminHistoryScreen(history: _controller.getHistory()),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── KOTAK IP SERVER ─────────────────────────────────────────
          _buildIpBanner(),

          // ── BANNER PEMENANG ──────────────────────────────────────────
          if (_controller.lastWinnerLabel != null)
            Container(
              width: double.infinity,
              color: Colors.green,
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pemenang Ronde ${_controller.roundNumber - 1}: ${_controller.lastWinnerLabel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // ── LIST PESERTA ─────────────────────────────────────────────
          Expanded(
            child: _controller.groups.isEmpty
                ? const Center(
                    child: Text(
                      'Menunggu peserta terhubung...\n\nBagikan IP di atas ke peserta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _controller.groups.length,
                    itemBuilder: (context, index) {
                      final group = _controller.groups[index];
                      return ListTile(
                        leading: Icon(
                          Icons.circle,
                          color:
                              group.isConnected ? Colors.green : Colors.red,
                          size: 14,
                        ),
                        title: Text(group.label),
                        subtitle: Text(
                          group.isConnected ? 'Terhubung' : 'Terputus',
                          style: TextStyle(
                            color: group.isConnected
                                ? Colors.green
                                : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _showRenameDialog(group.id, group.label),
                        ),
                      );
                    },
                  ),
          ),

          // ── TOMBOL RESET ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _controller.resetRound,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.orange,
              ),
              child: const Text(
                'RESET RONDE / GANTI SOAL',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpBanner() {
    final ip = _controller.serverIp;
    final isRunning = _controller.isServerRunning;

    return Container(
      width: double.infinity,
      color: isRunning ? Colors.blue.shade700 : Colors.grey.shade400,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRunning ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isRunning ? 'Server Aktif' : 'Memulai server...',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (ip != null) ...
            [
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: ip));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('IP disalin ke clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'IP: $ip',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy, color: Colors.white70, size: 18),
                  ],
                ),
              ),
              const Text(
                'Ketuk IP untuk menyalin → bagikan ke peserta',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
        ],
      ),
    );
  }

  void _showRenameDialog(String groupId, String currentLabel) {
    final controller = TextEditingController(text: currentLabel);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ubah Nama Grup'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nama grup baru'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _controller.renameGroup(groupId, controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
