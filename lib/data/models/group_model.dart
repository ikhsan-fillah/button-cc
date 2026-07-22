class GroupModel {
  final String id;
  String label;
  bool isConnected;
  int? pressTimestamp;

  GroupModel({
    required this.id,
    required this.label,
    this.isConnected = false,
    this.pressTimestamp,
  });

  GroupModel copyWith({String? label, bool? isConnected, int? pressTimestamp}) {
    return GroupModel(
      id: id,
      label: label ?? this.label,
      isConnected: isConnected ?? this.isConnected,
      pressTimestamp: pressTimestamp ?? this.pressTimestamp,
    );
  }
}
