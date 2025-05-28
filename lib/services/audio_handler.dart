import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler {
  late final AudioPlayer player;

  MyAudioHandler() {
    player = AudioPlayer();
    _notifyAudioHandlerAboutPlaybackEvents();
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    player.playerStateStream.listen((playerState) {
      final playing = playerState.playing;
      final processingState = playerState.processingState;

      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.play,
            MediaControl.pause,
            MediaControl.stop,
          ],
          androidCompactActionIndices: const [0, 1, 2],
          processingState: {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[processingState]!,
          playing: playing,
          updatePosition: player.position,
          bufferedPosition: player.bufferedPosition,
          speed: player.speed,
          queueIndex: null,
        ),
      );
    });
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() => player.stop();
}
