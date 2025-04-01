import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class AnimatedGifWidget extends StatefulWidget {
  final String gifAssetPath;

  const AnimatedGifWidget({super.key, required this.gifAssetPath});

  @override
  State<StatefulWidget> createState() => _AnimatedGifWidgetState();
}

class _AnimatedGifWidgetState extends State<AnimatedGifWidget> {
  late List<img.Image> frames;
  bool isStateOne = true;

  @override
  void initState() {
    super.initState();
    _loadGif();
  }

  Future<void> _loadGif() async {
    final data = await DefaultAssetBundle.of(context).load(widget.gifAssetPath);
    final bytes = data.buffer.asUint8List();
    final gif = img.decodeGif(Uint8List.fromList(bytes));
    if (gif != null) {
      setState(() {
        frames = gif.frames;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (frames.isEmpty) {
      return Container(); // Placeholder while frames are loading
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          isStateOne = !isStateOne;
        });
      },
      child: Image.memory(Uint8List.fromList(img.encodeGif(frames[isStateOne ? 0 : 1]))),
    );
  }
}