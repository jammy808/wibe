import 'dart:io';
import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../services/playlist_storage.dart';
import 'package:path/path.dart' as p;

class CreatePlaylistScreen extends StatefulWidget {
  final List<File> allSongs;

  CreatePlaylistScreen({required this.allSongs});

  @override
  _CreatePlaylistScreenState createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends State<CreatePlaylistScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> selectedPaths = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Playlist")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Playlist Name"),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.allSongs.length,
              itemBuilder: (context, index) {
                final file = widget.allSongs[index];
                final isSelected = selectedPaths.contains(file.path);

                return CheckboxListTile(
                  title: Text(p.basename(file.path)),
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val!) {
                        selectedPaths.add(file.path);
                      } else {
                        selectedPaths.remove(file.path);
                      }
                    });
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty && selectedPaths.isNotEmpty) {
                final newPlaylist = Playlist(name: _nameController.text, songPaths: selectedPaths.toList());
                final existing = await PlaylistStorage.loadPlaylists();
                existing.add(newPlaylist);
                await PlaylistStorage.savePlaylists(existing);
                Navigator.pop(context);
              }
            },
            child: Text("Save Playlist"),
          )
        ],
      ),
    );
  }
}
