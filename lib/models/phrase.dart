import 'package:hive_ce/hive.dart';

part 'phrase.g.dart';

@HiveType(typeId: 0)
class Phrase extends HiveObject {
  Phrase({
    required this.id,
    required this.text,
    required this.audioFileName,
    required this.createdAt,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String text;

  /// File name only (e.g. `"<uuid>.m4a"`), not a full path — the
  /// documents-directory path can change between app installs.
  @HiveField(2)
  final String audioFileName;

  @HiveField(3)
  final DateTime createdAt;
}
