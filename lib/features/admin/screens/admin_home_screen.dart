import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/admin_controller.dart';
import '../../../services/permission_service.dart';
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
    _listener = () {
      if (mounted) setState(() {});
    };
    _controller.addListener(_listener);
    // Minta permission dulu, baru start server
    _initWithPermission();
  }

  Future<void> _initWithPermission() async {
    // Tunggu permission selesai sebelum server di-bind ke port
    await PermissionService.requestOnAppStart();
    if (mounted) _controller.startServer();
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
          _buildIpBanner(),
          _buildWinnerBanner(),
          Expanded(child: _buildGroupList()),
          _buildResetButton(),
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
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isRunning ? 'Server Aktif' : 'Memulai server...',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
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

  Widget _buildWinnerBanner() {
    if (_controller.lastWinnerLabel == null) return const SizedBox.shrink();
    final order = _controller.lastPressOrderLabels;
    return Container(
      width: double.infinity,
      color: Colors.green.shade700,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '\ud83c\udfc6 Pemenang Ronde ${_controller.roundNumber - 1}: ${_controller.lastWinnerLabel}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (order.isNotEmpty) ...
            [
              const SizedBox(height: 6),
              Text(
                'Urutan: ${order.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('  \u2192  ')}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildGroupList() {
    if (!_controller.isServerRunning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Memulai server...\nMohon tunggu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    if (_controller.groups.isEmpty) {
      return const Center(
        child: Text(
          'Menunggu peserta terhubung...\n\nBagikan IP di atas ke peserta.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _controller.groups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final group = _controller.groups[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor:
                group.isConnected ? Colors.green : Colors.red.shade300,
            child: Icon(
              group.isConnected ? Icons.person : Icons.person_off,
              color: Colors.white,
              size: 16,
            ),
          ),
          title: Text(
            group.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            group.isConnected ? '\u25cf Terhubung' : '\u25cb Terputus',
            style: TextStyle(
              color: group.isConnected ? Colors.green : Colors.red,
              fontSize: 12,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Ubah nama',
                onPressed: () => _showRenameDialog(group.id, group.label),
              ),
              IconButton(
                icon: const Icon(Icons.person_remove_outlined,
                    size: 20, color: Colors.red),
                tooltip: 'Keluarkan peserta',
                onPressed: () => _showKickDialog(group.id, group.label),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResetButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ElevatedButton.icon(
        onPressed: !_controller.isServerRunning
            ? null
            : () {
                _controller.resetRound();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Ronde ${_controller.roundNumber - 1} direset. Mulai ronde ${_controller.roundNumber}!'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
        icon: const Icon(Icons.refresh, color: Colors.white),
        label: const Text(
          'RESET RONDE / GANTI SOAL',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: Colors.orange,
        ),
      ),
    );
  }

  void _showRenameDialog(String groupId, String currentLabel) {
    final ctrl = TextEditingController(text: currentLabel);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ubah Nama Grup'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nama baru'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _controller.renameGroup(groupId, ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showKickDialog(String groupId, String label) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluarkan Peserta'),
        content:
            Text('Yakin ingin mengeluarkan "$label" dari sesi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _controller.kickGroup(groupId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label telah dikeluarkan.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Keluarkan'),
          ),
        ],
      ),
    );
  }
}
