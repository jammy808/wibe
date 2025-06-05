import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path/path.dart' as path;
import '../models/song_data.dart';
import 'now_playing.dart';
import 'package:wibe/screens/playlist_screen.dart';
import 'youtube_downloader_screen.dart';
import '../services/audio_player_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _audioPlayer = globalAudioPlayer;
  final ScrollController _scrollController = ScrollController();
  List<SongData> _songs = [];
  List<SongData> _filteredSongs = [];
  ConcatenatingAudioSource? _playlist;
  int? _currentIndex;
  bool _isLoading = true;
  bool _isPreparing = false;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _preparePlaylist().then((_) {
      _audioPlayer.currentIndexStream.listen((index) {
        setState(() {
          _currentIndex = index;
        });
      });
    });
  }

  Future<void> _preparePlaylist() async {
    try {
      final directory = Directory('/storage/emulated/0/Music/');
      final files = directory
          .listSync()
          .where((entity) =>
              entity is File &&
              (entity.path.endsWith('.mp3') || entity.path.endsWith('.m4a')))
          .cast<File>()
          .toList();

      setState(() {
        _songs = [];
        _isLoading = false;
        _isPreparing = true;
      });

      List<SongData> tempSongs = [];

      for (var file in files) {
        final metadata = await MetadataRetriever.fromFile(file);
        final title = metadata.trackName ?? path.basename(file.path);
        final coverImage = metadata.albumArt;
        Color dominantColor = const Color.fromARGB(206, 109, 109, 109);

        if (coverImage != null) {
          final palette = await PaletteGenerator.fromImageProvider(
            MemoryImage(coverImage),
            size: const Size(200, 200),
          );
          dominantColor = palette.dominantColor?.color ?? dominantColor;
        }

        final song = SongData(
          file: file,
          title: title,
          coverImage: coverImage,
          dominantColor: dominantColor,
        );

        tempSongs.add(song);

        setState(() {
          _songs = List.from(tempSongs);
          _filteredSongs = _filterSongs(_searchQuery);
        });
      }

      final playlist = ConcatenatingAudioSource(
        children: tempSongs
            .map((song) => AudioSource.uri(
                  Uri.file(song.file.path),
                  tag: MediaItem(
                    id: song.file.path,
                    album: "Local Music",
                    title: song.title,
                    artUri: Uri.parse('https://example.com/artwork.png'),
                  ),
                ))
            .toList(),
      );

      await _audioPlayer.stop();
      await _audioPlayer.setAudioSource(playlist);

      setState(() {
        _playlist = playlist;
        _isPreparing = false;
      });
    } catch (e, st) {
      print('Error preparing playlist: $e\n$st');
      setState(() {
        _isLoading = false;
        _isPreparing = false;
      });
    }
  }

  void _playSong(int index) {
    if (_playlist == null) return;

    final originalIndex = _songs.indexOf(_filteredSongs[index]);
    _audioPlayer.seek(Duration.zero, index: originalIndex);
    _audioPlayer.play();
  }

  List<SongData> _filterSongs(String query) {
    return _songs
        .where((song) => song.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
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
    if (_currentIndex == null || _playlist == null) return const SizedBox.shrink();
    if (_currentIndex! < 0 || _currentIndex! >= _songs.length) return const SizedBox.shrink();

    final song = _songs[_currentIndex!];

    return SafeArea(
      bottom: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.black, song.dominantColor],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NowPlayingScreen(
                  player: _audioPlayer,
                  playlist: _playlist!,
                  songs: _songs,
                ),
              ),
            );
          },
          child: Row(
            children: [
              const SizedBox(width: 10), // left margin for cover
              CircleAvatar(
                backgroundImage: song.coverImage != null ? MemoryImage(song.coverImage!) : null,
                child: song.coverImage == null ? const Icon(Icons.music_note) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  song.title,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StreamBuilder<bool>(
                stream: _audioPlayer.playingStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
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
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Music")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipPath(
          clipper: _BottomCurveClipper(),
          child: AppBar(
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _currentIndex != null &&
                          _currentIndex! >= 0 &&
                          _currentIndex! < _songs.length
                      ? [Colors.black87, _songs[_currentIndex!].dominantColor]
                      : [Colors.deepPurple, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: !_isSearching
                ? const Text(
                    "Music",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )
                : TextField(
                    autofocus: true,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filteredSongs = _filterSongs(value);
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search songs...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchQuery = '';
                      _filteredSongs = _filterSongs('');
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    } else {
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (_filteredSongs.isNotEmpty) {
                          _scrollController.animateTo(
                            120,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.playlist_play),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistsScreen(allSongs: _songs),
                    ),
                  );
                  await _audioPlayer.stop();
                  await _audioPlayer.setAudioSource(_playlist!);
                },
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const YouTubeDownloader(),
                    ),
                  );
                  await _audioPlayer.stop();
                  await _audioPlayer.setAudioSource(_playlist!);
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _filteredSongs.isEmpty
                ? const Center(child: Text('No songs found.'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _filteredSongs.length + (_isPreparing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isPreparing && index == _filteredSongs.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'Loading more songs...',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                        );
                      }

                      final song = _filteredSongs[index];
                      final isPlaying = _currentIndex != null &&
                          _songs[_currentIndex!] == song &&
                          _audioPlayer.playing;

                      return ListTile(
                        tileColor: isPlaying ? song.dominantColor.withOpacity(0.4) : null,
                        leading: CircleAvatar(
                          backgroundImage:
                              song.coverImage != null ? MemoryImage(song.coverImage!) : null,
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
          _buildMiniPlayer(),
        ],
      ),
    );
  }
}

// Custom clipper for curved AppBar bottom edges
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
