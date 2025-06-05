import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class YouTubeDownloader extends StatefulWidget {
  const YouTubeDownloader({super.key});

  @override
  State<YouTubeDownloader> createState() => _YouTubeDownloaderState();
}

class _YouTubeDownloaderState extends State<YouTubeDownloader> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  Future<void> _downloadAudio(String url) async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    final yt = YoutubeExplode();

    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      final audioStream = yt.videos.streamsClient.get(audioStreamInfo);

      final dir = await getExternalStorageDirectory();
      final sanitizedTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${dir!.path}/$sanitizedTitle.m4a';

      final file = File(filePath);
      final output = file.openWrite();
      await audioStream.pipe(output);
      await output.flush();
      await output.close();

      final musicDir = Directory('/storage/emulated/0/Music');
      if (!(await musicDir.exists())) {
        await musicDir.create(recursive: true);
      }

      final newFilePath = '${musicDir.path}/$sanitizedTitle.m4a';
      await file.copy(newFilePath);
      await file.delete();

      setState(() {
        _message = '✅ Downloaded to:\n$newFilePath';
      });
    } catch (e) {
      setState(() {
        _message = '❌ Download failed: $e';
        print('Download failed: $e');
      });
    } finally {
      yt.close();
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 165, 0, 0), Colors.deepOrangeAccent],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
        ),
        title: const Text('YouTube MP3 Downloader'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Enter YouTube URL',
                        prefixIcon: const Icon(Icons.link),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : () => _downloadAudio(_controller.text),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.redAccent, Colors.deepOrange],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Download MP3',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_message.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _message.startsWith('✅')
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _message.startsWith('✅') ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Text(
                          _message,
                          style: TextStyle(
                            color: _message.startsWith('✅') ? Colors.green[700] : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
