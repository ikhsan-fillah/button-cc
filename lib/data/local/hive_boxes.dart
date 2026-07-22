import 'package:hive_flutter/hive_flutter.dart';
import '../models/round_result_model.dart';

class HiveBoxes {
  static const String roundHistoryBox = 'round_history_box';
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return; // Guard: jangan init dua kali (hot restart)
    _initialized = true;

    await Hive.initFlutter();

    // Cek apakah adapter sudah terdaftar sebelum register
    // (mencegah HiveError saat hot restart di development)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(RoundResultModelAdapter());
    }

    // isOpen check: jangan buka box yang sudah terbuka
    if (!Hive.isBoxOpen(roundHistoryBox)) {
      await Hive.openBox<RoundResultModel>(roundHistoryBox);
    }
  }

  static Box<RoundResultModel> get roundHistory =>
      Hive.box<RoundResultModel>(roundHistoryBox);
}
