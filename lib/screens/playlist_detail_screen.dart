//import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/playlist.dart';
import '../services/audio_player_service.dart';
import 'now_playing.dart';
import 'package:path/path.dart' as path;

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  PlaylistDetailScreen({required this.playlist});

  @override
  _PlaylistDetailScreenState createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final _audioPlayer = globalAudioPlayer;
  ConcatenatingAudioSource? _playlistSource;
  int? _currentIndex;

  @override
  void initState() {
    super.initState();
    _preparePlaylist();

    _audioPlayer.currentIndexStream.listen((index) {
      setState(() {
        _currentIndex = index;
      });
    });

    _audioPlayer.playerStateStream.listen((_) {
      setState(() {});
    });
  }

  Future<void> _preparePlaylist() async {
    final audioSources = widget.playlist.songPaths.map((songPath) {
      return AudioSource.uri(
        Uri.file(songPath),
        tag: MediaItem(
          id: songPath,
          album: widget.playlist.name,
          title: path.basenameWithoutExtension(songPath),
        ),
      );
    }).toList();

    _playlistSource = ConcatenatingAudioSource(children: audioSources);

    await _audioPlayer.setAudioSource(_playlistSource!);
  }

  void _playSong(int index) async {
    await _audioPlayer.seek(Duration.zero, index: index);
    _audioPlayer.play();
  }

  void _stopSong() async {
    await _audioPlayer.stop();
    setState(() {
      _currentIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.playlist.name)),
      body: Column(
        children: [
          Expanded(
            child: widget.playlist.songPaths.isEmpty
                ? Center(child: Text("No songs in this playlist"))
                : ListView.builder(
                    itemCount: widget.playlist.songPaths.length,
                    itemBuilder: (context, index) {
                      final songPath = widget.playlist.songPaths[index];
                      final songName = path.basename(songPath);
                      final isPlaying = _currentIndex == index && _audioPlayer.playing;

                      return ListTile(
                        title: Text(songName),
                        trailing: isPlaying
                            ? IconButton(
                                icon: Icon(Icons.stop),
                                onPressed: _stopSong,
                              )
                            : IconButton(
                                icon: Icon(Icons.play_arrow),
                                onPressed: () => _playSong(index),
                              ),
                      );
                    },
                  ),
          ),
          if (_currentIndex != null) _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final songPath = widget.playlist.songPaths[_currentIndex!];
    final songName = path.basename(songPath);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              player: _audioPlayer,
              playlist: _playlistSource!,
            ),
          ),
        );
      },
      child: Container(
        color: Colors.grey.shade900,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.music_note, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                songName,
                style: TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            StreamBuilder<PlayerState>(
              stream: _audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data?.playing ?? false;
                return IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
