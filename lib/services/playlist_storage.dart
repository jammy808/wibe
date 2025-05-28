import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';

class PlaylistStorage {
  static const String key = 'user_playlists';

  static Future<List<Playlist>> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data == null) return [];
    final decoded = jsonDecode(data);
    return (decoded as List).map((e) => Playlist.fromJson(e)).toList();
  }

  static Future<void> savePlaylists(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(playlists.map((e) => e.toJson()).toList());
    await prefs.setString(key, encoded);
  }
}
