class Playlist {
  final String name;
  final List<String> songPaths;

  Playlist({required this.name, required this.songPaths});

  Map<String, dynamic> toJson() => {
        'name': name,
        'songPaths': songPaths,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      name: json['name'],
      songPaths: List<String>.from(json['songPaths']),
    );
  }
}
