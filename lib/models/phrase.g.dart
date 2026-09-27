// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phrase.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhraseAdapter extends TypeAdapter<Phrase> {
  @override
  final typeId = 0;

  @override
  Phrase read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Phrase(
      id: fields[0] as String,
      text: fields[1] as String,
      audioFileName: fields[2] as String,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Phrase obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.audioFileName)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhraseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
