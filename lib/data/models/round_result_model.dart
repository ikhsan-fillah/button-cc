import 'package:hive/hive.dart';

part 'round_result_model.g.dart';

@HiveType(typeId: 0)
class RoundResultModel extends HiveObject {
  @HiveField(0)
  final int roundNumber;

  @HiveField(1)
  final String winnerGroupLabel;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final List<String> pressOrderLog; // urutan lengkap semua grup yang pencet

  RoundResultModel({
    required this.roundNumber,
    required this.winnerGroupLabel,
    required this.timestamp,
    required this.pressOrderLog,
  });
}
