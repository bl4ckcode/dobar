import 'dart:async';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ColorExtractionService {
  static final ColorExtractionService _instance = ColorExtractionService._();
  static ColorExtractionService get instance => _instance;
  ColorExtractionService._();

  final Map<String, Color> _cache = {};

  static const Color defaultHeaderColor = Color(0xFFFF9800);
  static const Color defaultHeaderColorDark = Color(0xFFE65100);

  Future<Color> extractDominantColor(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return defaultHeaderColor;
    }

    if (_cache.containsKey(imageUrl)) {
      return _cache[imageUrl]!;
    }

    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100),
        maximumColorCount: 8,
      );

      Color dominantColor =
          paletteGenerator.vibrantColor?.color ??
          paletteGenerator.dominantColor?.color ??
          paletteGenerator.mutedColor?.color ??
          defaultHeaderColor;

      final hsl = HSLColor.fromColor(dominantColor);
      if (hsl.saturation < 0.2 || hsl.lightness > 0.8 || hsl.lightness < 0.2) {
        dominantColor = defaultHeaderColor;
      }

      _cache[imageUrl] = dominantColor;
      return dominantColor;
    } catch (e) {
      return defaultHeaderColor;
    }
  }

  LinearGradient createHeaderGradient(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    final darkerColor = hsl
        .withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0))
        .toColor();

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [baseColor, darkerColor],
    );
  }

  void clearCache() {
    _cache.clear();
  }
}
