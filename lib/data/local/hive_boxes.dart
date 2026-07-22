import 'package:hive_flutter/hive_flutter.dart';
import '../models/round_result_model.dart';

class HiveBoxes {
  static const String roundHistoryBox = 'round_history_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(RoundResultModelAdapter());
    await Hive.openBox<RoundResultModel>(roundHistoryBox);
  }

  static Box<RoundResultModel> get roundHistory =>
      Hive.box<RoundResultModel>(roundHistoryBox);
}
