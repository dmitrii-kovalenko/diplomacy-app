class GameModel {
  final String id;
  final String name;
  final String? shareId;
  final String? mapName;
  final String? phase;
  final String? deadline;
  final bool isSandbox;
  final bool isPrivate;

  GameModel({
    required this.id,
    required this.name,
    this.shareId,
    this.mapName,
    this.phase,
    this.deadline,
    this.isSandbox = false,
    this.isPrivate = false,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      shareId: json['share_id'],
      mapName: json['map_name'] ?? json['map']?['name'],
      phase: json['phase'],
      deadline: json['deadline'],
      isSandbox: json['is_sandbox'] ?? false,
      isPrivate: json['is_private'] ?? false,
    );
  }
}
