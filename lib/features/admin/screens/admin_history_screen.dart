import 'package:flutter/material.dart';
import '../../../data/models/round_result_model.dart';

class AdminHistoryScreen extends StatelessWidget {
  final List<RoundResultModel> history;
  const AdminHistoryScreen({super.key, required this.history});

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Ronde')),
      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada riwayat ronde.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Riwayat akan muncul setelah ronde selesai.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                // Tampilkan dari yang terbaru
                final r = history[history.length - 1 - index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      '${r.roundNumber}',
                      style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    '🏆 ${r.winnerGroupLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Urutan: ${r.pressOrderLog.join(' → ')}\n${_formatTime(r.timestamp)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                );
              },
            ),
    );
  }
}
