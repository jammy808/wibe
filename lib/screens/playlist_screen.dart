import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
//import 'package:path/path.dart' as p;
import 'package:wibe/screens/playlist_detail_screen.dart';
import '../models/playlist.dart';
import '../services/playlist_storage.dart';
//import 'now_playing.dart';
import 'create_playlist_screen.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../services/audio_player_service.dart';


class PlaylistsScreen extends StatefulWidget {
  final List<File> allSongs;

  PlaylistsScreen({required this.allSongs});

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
          SnackBar(content: Text('Playlist is empty')),
        );
        return;
      }

      final audioSources = playlist.songPaths.map((path) {
        return AudioSource.uri(
          Uri.file(path),
          tag: MediaItem(
            id: path,
            album: 'Playlist',
            title: path.split('/').last,
          ),
        );
      }).toList();

      final concatenated = ConcatenatingAudioSource(children: audioSources);

      await player.setAudioSource(concatenated);
      //await player.play();

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlist: playlist),
        ),
      );

    } catch (e) {
      print('Error playing playlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play playlist')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Playlists")),
      body: _playlists.isEmpty
          ? Center(child: Text("No playlists created yet."))
          : ListView.builder(
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                final playlist = _playlists[index];
                return ListTile(
                  title: Text(playlist.name),
                  subtitle: Text("${playlist.songPaths.length} songs"),
                  onTap: () {
                    print('Tapped playlist: ${playlist.name}');
                    _playPlaylist(playlist); 
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.playlist_add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePlaylistScreen(allSongs: widget.allSongs),
            ),
          );
          _loadPlaylists(); // Refresh after return
        },
      ),
    );
  }
}
