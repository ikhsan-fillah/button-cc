import 'package:flutter/material.dart';
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
      if (mounted) {
        setState(() {});
      }
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
          if (_controller.lastWinnerLabel != null)
            Container(
              width: double.infinity,
              color: Colors.green,
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pemenang Ronde ${_controller.roundNumber}: ${_controller.lastWinnerLabel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _controller.groups.length,
              itemBuilder: (context, index) {
                final group = _controller.groups[index];
                return ListTile(
                  leading: Icon(
                    Icons.circle,
                    color: group.isConnected ? Colors.green : Colors.red,
                    size: 14,
                  ),
                  title: Text(group.label),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showRenameDialog(group.id, group.label),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _controller.resetRound,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.orange,
              ),
              child: const Text('RESET RONDE / GANTI SOAL'),
            ),
          ),
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
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () {
              _controller.renameGroup(groupId, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
