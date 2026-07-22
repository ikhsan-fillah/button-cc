import '../models/round_result_model.dart';
import 'hive_boxes.dart';

class RoundHistoryRepository {
  Future<void> addResult(RoundResultModel result) async {
    await HiveBoxes.roundHistory.add(result);
  }

  List<RoundResultModel> getAllResults() {
    return HiveBoxes.roundHistory.values.toList();
  }

  Future<void> clearHistory() async {
    await HiveBoxes.roundHistory.clear();
  }
}
