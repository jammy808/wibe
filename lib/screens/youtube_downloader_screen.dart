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
      // Request storage permission
      // final status = await Permission.storage.request();
      // if (!status.isGranted) {
      //   setState(() {
      //     _message = 'Permission denied';
      //     _isLoading = false;
      //   });
      //   return;
      // }

      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      final audioStream = yt.videos.streamsClient.get(audioStreamInfo);

      // Safe directory
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

      // Optionally delete the original temp file
      await file.delete();

      setState(() {
        _message = 'Downloaded to:\n$newFilePath';
      });
    } catch (e) {
      setState(() {
        _message = 'Download failed: $e';
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
      appBar: AppBar(title: const Text('YouTube MP3 Downloader')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'YouTube URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _downloadAudio(_controller.text),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Download MP3'),
            ),
            const SizedBox(height: 16),
            if (_message.isNotEmpty)
              Text(
                _message,
                style: const TextStyle(color: Colors.green),
              ),
          ],
        ),
      ),
    );
  }
}
