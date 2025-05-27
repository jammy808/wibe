import 'package:just_audio/just_audio.dart';

class AudioPlayerService {
  static final _player = AudioPlayer();

  Future<void> play(String filePath) async {
    await _player.setFilePath(filePath);
    _player.play();
  }

  void pause() => _player.pause();

  void stop() => _player.stop();

  bool isPlaying() => _player.playing;
}
