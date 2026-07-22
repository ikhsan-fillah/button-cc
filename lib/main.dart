import 'package:flutter/material.dart';
import 'data/local/hive_boxes.dart';
import 'features/admin/screens/admin_home_screen.dart';
import 'features/player/screens/player_connect_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  runApp(const CerdasCermatApp());
}

class CerdasCermatApp extends StatelessWidget {
  const CerdasCermatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buzzer Cerdas Cermat',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const RoleSelectionScreen(),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Peran')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Jadi Admin (Server)'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlayerConnectScreen()),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Jadi Player (Grup)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
