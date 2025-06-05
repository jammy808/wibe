import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/playlist.dart';
import '../models/song_data.dart';
import '../services/playlist_storage.dart';
import '../services/audio_player_service.dart';
import 'create_playlist_screen.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  final List<SongData> allSongs;

  const PlaylistsScreen({super.key, required this.allSongs});

  @override
  _PlaylistsScreenState createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  List<Playlist> _playlists = [];

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  void _loadPlaylists() async {
    final playlists = await PlaylistStorage.loadPlaylists();
    setState(() {
      _playlists = playlists;
    });
  }

  void _playPlaylist(Playlist playlist) async {
    try {
      final player = globalAudioPlayer;

      if (playlist.songPaths.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist is empty')),
        );
        return;
      }

      await player.stop();

      final audioSources = playlist.songPaths.map((path) {
        final song = widget.allSongs.firstWhere(
          (s) => s.file.path == path,
          orElse: () => SongData(
            file: File(path),
            title: path.split('/').last,
            coverImage: null,
            dominantColor: const Color.fromARGB(206, 109, 109, 109),
          ),
        );

        return AudioSource.uri(
          Uri.file(song.file.path),
          tag: MediaItem(
            id: song.file.path,
            album: 'Playlist',
            title: song.title,
            artUri: Uri.parse('https://example.com/artwork.png'),
          ),
        );
      }).toList();

      final concatenated = ConcatenatingAudioSource(children: audioSources);
      await player.setAudioSource(concatenated, preload: true);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlist: playlist),
        ),
      );
    } catch (e) {
      print('Error playing playlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to play playlist')),
      );
    }
  }

  Future<void> _deletePlaylist(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Playlist"),
        content: const Text("Are you sure you want to delete this playlist?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed == true) {
      _playlists.removeAt(index);
      await PlaylistStorage.savePlaylists(_playlists);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Playlists")),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _playlists.isEmpty
            ? const Center(child: Text("No playlists created yet."))
            : ListView.builder(
                itemCount: _playlists.length,
                itemBuilder: (context, index) {
                  final playlist = _playlists[index];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      title: Text(
                        playlist.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        "${playlist.songPaths.length} songs",
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () => _playPlaylist(playlist),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreatePlaylistScreen(
                                  allSongs: widget.allSongs.map((s) => s.file).toList(),
                                  existingPlaylist: playlist,
                                ),
                              ),
                            );
                            if (updated == true) _loadPlaylists();
                          } else if (value == 'delete') {
                            await _deletePlaylist(index);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
       floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.playlist_add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePlaylistScreen(
                allSongs: widget.allSongs.map((s) => s.file).toList(),
              ),
            ),
          );
          _loadPlaylists();
        },
      ),
    );
  }
}
