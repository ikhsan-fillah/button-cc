import 'package:flutter/material.dart';
import '../../../data/models/round_result_model.dart';

class AdminHistoryScreen extends StatelessWidget {
  final List<RoundResultModel> history;
  const AdminHistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Ronde')),
      body: ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          final r = history[index];
          return ListTile(
            title: Text('Ronde ${r.roundNumber}: ${r.winnerGroupLabel} menang'),
            subtitle: Text(
              'Urutan pencet: ${r.pressOrderLog.join(' -> ')}\n${r.timestamp}',
            ),
          );
        },
      ),
    );
  }
}
