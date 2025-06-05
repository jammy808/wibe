import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song_data.dart'; // import your SongData model

class NowPlayingScreen extends StatefulWidget {
  final AudioPlayer player;
  final ConcatenatingAudioSource playlist;
  final List<SongData> songs;

  const NowPlayingScreen({
    super.key,
    required this.player,
    required this.playlist,
    required this.songs,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  late AudioPlayer _player;
  late ConcatenatingAudioSource _playlist;

  Uint8List? get _coverImage {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= widget.songs.length) return null;
    return widget.songs[index].coverImage;
  }

  Color get _dominantColor {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= widget.songs.length) return const Color(0xFF8A2BE2);
    return widget.songs[index].dominantColor;
  }

  @override
  void initState() {
    super.initState();
    _player = widget.player;
    _playlist = widget.playlist;
  }

  void _playPause() => _player.playing ? _player.pause() : _player.play();

  void _skipNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  void _skipPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  void _seekBy(Duration offset) {
    final current = _player.position;
    _player.seek(current + offset);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SequenceState?>(
      stream: _player.sequenceStateStream,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data?.currentSource?.tag as MediaItem?;
        final title = mediaItem?.title ?? "Unknown";

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Center(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black,
                  Colors.black,
                  _dominantColor,
                  Colors.black,
                ],
                stops: [0.0, 0.2, 0.7, 1.0],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circular image with circular progress
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final total = _player.duration ?? const Duration(seconds: 1);
                    final progress = (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

                    return SizedBox(
                      height: 290,
                      width: 290,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 290,
                            width: 290,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(_dominantColor),
                            ),
                          ),
                          CircleAvatar(
                            radius: 125,
                            backgroundColor: const Color.fromARGB(168, 255, 255, 255),
                            backgroundImage:
                                _coverImage != null ? MemoryImage(_coverImage!) : null,
                            child: _coverImage == null
                                ? const Icon(Icons.music_note, size: 80, color: Colors.white54)
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 80),

                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final total = _player.duration ?? Duration.zero;

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _dominantColor,
                            inactiveTrackColor: const Color.fromARGB(168, 255, 255, 255),
                            thumbColor: _dominantColor,
                            overlayColor: _dominantColor.withOpacity(0.2),
                          ),
                          child: Slider(
                            min: 0,
                            max: total.inMilliseconds.toDouble(),
                            value: position.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
                            onChanged: (value) {
                              _player.seek(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position), style: const TextStyle(color: Colors.white70)),
                              Text(_formatDuration(total), style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      color: Colors.white,
                      icon: const Icon(Icons.replay_10),
                      onPressed: () => _seekBy(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      iconSize: 40,
                      color: Colors.white,
                      icon: const Icon(Icons.skip_previous),
                      onPressed: _player.hasPrevious ? _skipPrevious : null,
                    ),
                    const SizedBox(width: 10),
                    StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        final processingState = snapshot.data?.processingState;

                        if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                          return Container(
                            margin: const EdgeInsets.all(8.0),
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(color: _dominantColor),
                          );
                        } else if (!playing) {
                          return IconButton(
                            iconSize: 64,
                            color: Colors.white,
                            icon: const Icon(Icons.play_circle),
                            onPressed: _playPause,
                          );
                        } else {
                          return IconButton(
                            iconSize: 64,
                            color: Colors.white,
                            icon: const Icon(Icons.pause_circle),
                            onPressed: _playPause,
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      iconSize: 40,
                      color: Colors.white,
                      icon: const Icon(Icons.skip_next),
                      onPressed: _player.hasNext ? _skipNext : null,
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      iconSize: 32,
                      color: Colors.white,
                      icon: const Icon(Icons.forward_10),
                      onPressed: () => _seekBy(const Duration(seconds: 10)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
