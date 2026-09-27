import 'package:just_audio/just_audio.dart';

/// Thin wrapper around [AudioPlayer] from the `just_audio` package.
class PlayerService {
  PlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  Future<void> play(String path) async {
    await _player.setFilePath(path);
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.play();

  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> dispose() => _player.dispose();
}
