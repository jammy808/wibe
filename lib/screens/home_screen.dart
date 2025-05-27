import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wibe/screens/now_playing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> songs = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  ConcatenatingAudioSource? _playlist;
  int? _currentIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestPermissionAndFetchSongs();
    });

    // Listen to current song changes
    _audioPlayer.currentIndexStream.listen((index) {
      if (mounted) {
        setState(() {
          _currentIndex = index;
        });
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      setState(() {}); // Update UI for play/pause
    });
  }

  Future<void> requestPermissionAndFetchSongs() async {
    bool permissionGranted = false;

    try {
      if (Platform.isAndroid) {
        var androidVersion = int.tryParse(
              Platform.operatingSystemVersion.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 2),
            ) ??
            0;

        if (androidVersion >= 11) {
          final manageExternal = await Permission.manageExternalStorage.request();
          permissionGranted = manageExternal.isGranted;
        } else {
          final storage = await Permission.storage.request();
          permissionGranted = storage.isGranted;
        }
      }

      if (permissionGranted) {
        await fetchSongs();
        await preparePlaylist();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
        }
      }
    } catch (e) {
      print("Permission request error: $e");
    }
  }

  Future<void> fetchSongs() async {
    Directory downloadDir = Directory("/storage/emulated/0/Download");
    List<File> foundSongs = [];

    try {
      await for (var entity in downloadDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.mp3')) {
          foundSongs.add(entity);
        }
      }
    } catch (e) {
      print("Error while listing files: $e");
    }

    if (mounted) {
      setState(() {
        songs = foundSongs;
      });
    }
  }

  Future<void> preparePlaylist() async {
    if (songs.isEmpty) return;

    // Create playlist with metadata tags for just_audio_background
    _playlist = ConcatenatingAudioSource(
      children: songs.map((song) {
        final songTitle = path.basenameWithoutExtension(song.path);
        return AudioSource.uri(
          Uri.file(song.path),
          tag: MediaItem(
            id: song.path,
            album: "Local Music",
            title: songTitle,
            artUri: Uri.parse('https://example.com/artwork.png'), // placeholder art
          ),
        );
      }).toList(),
    );

    await _audioPlayer.setAudioSource(_playlist!);
  }

  void playSongAtIndex(int index) async {
    if (_playlist == null) return;

    await _audioPlayer.seek(Duration.zero, index: index);
    _audioPlayer.play();
  }

  void stopSong() async {
    await _audioPlayer.stop();
    setState(() {
      _currentIndex = null;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Music Player")),
      body: Column(
        children: [
          Expanded(
            child: songs.isEmpty
                ? const Center(child: Text("No songs found or permission not granted"))
                : ListView.builder(
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      final songName = path.basename(song.path);
                      final isPlaying = _currentIndex == index && _audioPlayer.playing;

                      return ListTile(
                        title: Text(songName),
                        subtitle: Text(song.path),
                        trailing: isPlaying
                            ? IconButton(
                                icon: const Icon(Icons.stop),
                                onPressed: stopSong,
                              )
                            : IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () => playSongAtIndex(index),
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
    final currentSong = songs[_currentIndex!];
    final songName = path.basename(currentSong.path);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(
              player: _audioPlayer,
              playlist: _playlist!,
            ),
          ),
        );
      },
      child: Container(
        color: Colors.grey.shade900,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.music_note, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                songName,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            StreamBuilder<PlayerState>(
              stream: _audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data?.playing ?? false;

                return IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  onPressed: () {
                    if (isPlaying) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.play();
                    }
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
