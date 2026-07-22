// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'round_result_model.dart';

class RoundResultModelAdapter extends TypeAdapter<RoundResultModel> {
  @override
  final int typeId = 0;

  @override
  RoundResultModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoundResultModel(
      roundNumber: fields[0] as int,
      winnerGroupLabel: fields[1] as String,
      timestamp: fields[2] as DateTime,
      pressOrderLog: (fields[3] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, RoundResultModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.roundNumber)
      ..writeByte(1)
      ..write(obj.winnerGroupLabel)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.pressOrderLog);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoundResultModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
