import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class SongData {
  final File file;
  final String title;
  final Uint8List? coverImage;
  final Color dominantColor;

  SongData({
    required this.file,
    required this.title,
    required this.coverImage,
    required this.dominantColor,
  });
}
