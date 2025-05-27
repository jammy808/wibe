import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class NowPlayingScreen extends StatefulWidget {
  final AudioPlayer player;
  final ConcatenatingAudioSource playlist;

  const NowPlayingScreen({
    super.key,
    required this.player,
    required this.playlist,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  late AudioPlayer _player;
  late ConcatenatingAudioSource _playlist;

  @override
  void initState() {
    super.initState();
    _player = widget.player;
    _playlist = widget.playlist;
  }

  void _playPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _skipNext() {
    final hasNext = _player.hasNext;
    if (hasNext) {
      _player.seekToNext();
    }
  }

  void _skipPrevious() {
    final hasPrevious = _player.hasPrevious;
    if (hasPrevious) {
      _player.seekToPrevious();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Now Playing"),
      ),
      body: StreamBuilder<SequenceState?>(
        stream: _player.sequenceStateStream,
        builder: (context, snapshot) {
          final sequenceState = snapshot.data;
          final currentSource = sequenceState?.currentSource;
          final mediaItem = currentSource?.tag as MediaItem?;

          final title = mediaItem?.title ?? "Unknown";
          final artworkUri = mediaItem?.artUri;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (artworkUri != null)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Image.network(
                    artworkUri.toString(),
                    height: 250,
                    width: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 250),
                  ),
                )
              else
                const Icon(Icons.music_note, size: 250),

              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Progress bar with duration and position
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final total = _player.duration ?? Duration.zero;

                  return Column(
                    children: [
                      Slider(
                        min: 0,
                        max: total.inMilliseconds.toDouble(),
                        value: position.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
                        onChanged: (value) {
                          _player.seek(Duration(milliseconds: value.toInt()));
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position)),
                            Text(_formatDuration(total)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // Playback controls: previous, play/pause, next
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _player.hasPrevious ? _skipPrevious : null,
                  ),
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      final processingState = snapshot.data?.processingState;

                      if (processingState == ProcessingState.loading ||
                          processingState == ProcessingState.buffering) {
                        return Container(
                          margin: const EdgeInsets.all(8.0),
                          width: 64,
                          height: 64,
                          child: const CircularProgressIndicator(),
                        );
                      } else if (!playing) {
                        return IconButton(
                          iconSize: 64,
                          icon: const Icon(Icons.play_arrow),
                          onPressed: _playPause,
                        );
                      } else {
                        return IconButton(
                          iconSize: 64,
                          icon: const Icon(Icons.pause),
                          onPressed: _playPause,
                        );
                      }
                    },
                  ),
                  IconButton(
                    iconSize: 48,
                    icon: const Icon(Icons.skip_next),
                    onPressed: _player.hasNext ? _skipNext : null,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
