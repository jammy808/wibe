import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as path;
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import '../models/playlist.dart';
import '../models/song_data.dart';
import '../services/audio_player_service.dart';
import 'now_playing.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  PlaylistDetailScreen({required this.playlist});

  @override
  _PlaylistDetailScreenState createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final _audioPlayer = globalAudioPlayer;
  ConcatenatingAudioSource? _playlistSource;
  List<SongData> _songs = [];
  int? _currentIndex;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _preparePlaylist();
    _audioPlayer.currentIndexStream.listen((index) {
      setState(() => _currentIndex = index);
    });
    _audioPlayer.playerStateStream.listen((_) {
      setState(() {});
    });
  }

  Future<void> _preparePlaylist() async {
    List<SongData> songs = [];

    for (var songPath in widget.playlist.songPaths) {
      final file = File(songPath);
      final metadata = await MetadataRetriever.fromFile(file);
      final title = metadata.trackName ?? path.basename(songPath);
      final coverImage = metadata.albumArt;
      Color dominantColor = const Color.fromARGB(206, 109, 109, 109);

      if (coverImage != null) {
        final palette = await PaletteGenerator.fromImageProvider(
          MemoryImage(coverImage),
          size: const Size(200, 200),
        );
        dominantColor = palette.dominantColor?.color ?? dominantColor;
      }

      songs.add(SongData(
        file: file,
        title: title,
        coverImage: coverImage,
        dominantColor: dominantColor,
      ));
    }

    final audioSources = songs.map((song) {
      return AudioSource.uri(
        Uri.file(song.file.path),
        tag: MediaItem(
          id: song.file.path,
          album: widget.playlist.name,
          title: song.title,
        ),
      );
    }).toList();

    await _audioPlayer.stop();

    _playlistSource = ConcatenatingAudioSource(children: audioSources);
    await _audioPlayer.setAudioSource(_playlistSource!);

    setState(() {
      _songs = songs;
      _isLoading = false;
    });
  }

  void _playSong(int index) async {
    await _audioPlayer.seek(Duration.zero, index: index);
    _audioPlayer.play();
  }

  Color lightenColor(Color color, [double amount = 0.3]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final lightenedHsl = hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0),
    );
    return lightenedHsl.toColor();
  }

  Widget _buildMiniPlayer() {
  if (_currentIndex == null || _currentIndex! >= _songs.length) return const SizedBox.shrink();
  final song = _songs[_currentIndex!];

  final isPlaying = _audioPlayer.playerState.playing;

  return SafeArea(
    bottom: true,
    child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              player: _audioPlayer,
              playlist: _playlistSource!,
              songs: _songs,
            ),
          ),
        );
      },
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.black87, song.dominantColor],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 4), // slight left padding
            CircleAvatar(
              radius: 22,
              backgroundImage: song.coverImage != null ? MemoryImage(song.coverImage!) : null,
              backgroundColor: Colors.grey[800],
              child: song.coverImage == null
                  ? const Icon(Icons.music_note, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                song.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                setState(() {}); // for icon refresh
              },
            ),
          ],
        ),
      ),
    ),
  );
}



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.playlist.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final Color appBarColor = (_currentIndex != null &&
            _currentIndex! >= 0 &&
            _currentIndex! < _songs.length)
        ? _songs[_currentIndex!].dominantColor
        : Colors.deepPurple;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipPath(
          clipper: _BottomCurveClipper(),
          child: AppBar(
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, appBarColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: Text(widget.playlist.name),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _songs.isEmpty
                ? const Center(child: Text("No songs in this playlist"))
                : ListView.builder(
                    itemCount: _songs.length,
                    itemBuilder: (context, index) {
                      final song = _songs[index];
                      final isPlaying = _currentIndex == index && _audioPlayer.playing;

                      return ListTile(
                        tileColor: isPlaying ? song.dominantColor.withOpacity(0.4) : null,
                        leading: CircleAvatar(
                          backgroundImage: song.coverImage != null ? MemoryImage(song.coverImage!) : null,
                          child: song.coverImage == null ? const Icon(Icons.music_note) : null,
                        ),
                        title: Text(
                          song.title,
                          overflow: TextOverflow.ellipsis,
                          style: isPlaying
                              ? TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: lightenColor(song.dominantColor, 0.4),
                                )
                              : null,
                        ),
                        onTap: () => _playSong(index),
                      );
                    },
                  ),
          ),
          if (_currentIndex != null) _buildMiniPlayer(),
        ],
      ),
    );
  }
}

// For AppBar curve
class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 10)
      ..quadraticBezierTo(size.width / 2, size.height + 10, size.width, size.height - 10)
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
