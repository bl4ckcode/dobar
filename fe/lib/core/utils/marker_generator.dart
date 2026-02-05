import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MarkerGenerator {
  static const int _markerSize = 150;
  static const double _borderWidth = 8.0;

  /// Creates a BitmapDescriptor from a URL or fallback asset.
  /// Draws the image in a circle with a branded border.
  static Future<BitmapDescriptor> createCustomMarkerBitmap(
    String? imageUrl, {
    required String fallbackAssetPath,
    required Color borderColor,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();
    final double size = _markerSize.toDouble();
    final double radius = size / 2;

    // 1. Draw Border (Gradient or Solid)
    // For "Instagram look", we often use a gradient, but we'll use solid color first
    // or a linear gradient if requested. Sticking to solid branded color for simplicity/reliability.
    paint.color = borderColor;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    // 2. Draw White Warning/Padding ring (optional, to separate image from border)
    paint.color = Colors.white;
    canvas.drawCircle(Offset(radius, radius), radius - _borderWidth + 2, paint);

    // 3. Load Image
    ui.Image? image;
    try {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        image = await _loadNetworkImage(imageUrl);
      }
    } catch (e) {
      debugPrint('Error loading network image for marker: $e');
    }

    // Fallback if network failed or null
    if (image == null) {
      image = await _loadAssetImage(fallbackAssetPath);
    }

    if (image != null) {
      // 4. Clip Path for Circular Image
      final Path clipPath = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(radius, radius),
            radius: radius - _borderWidth,
          ),
        );
      canvas.clipPath(clipPath);

      // 5. Draw Image
      // Resize logic: cover

      // We want to draw into the circle rect
      paint.filterQuality = FilterQuality.high;

      // Calculate source and destination rects
      // Destination is the circle area
      final Rect destRect = Rect.fromCircle(
        center: Offset(radius, radius),
        radius: radius - _borderWidth,
      );

      // Helper to paint image fitting the rect
      _paintImage(canvas, destRect, image!, paint, BoxFit.cover);
    }

    // Convert to BitmapDescriptor
    final img = await pictureRecorder.endRecording().toImage(
      _markerSize,
      _markerSize,
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  static Future<ui.Image?> _loadNetworkImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final Completer<ui.Image> completer = Completer();
      ui.decodeImageFromList(response.bodyBytes, (ui.Image img) {
        completer.complete(img);
      });
      return completer.future;
    }
    return null;
  }

  static Future<ui.Image> _loadAssetImage(String path) async {
    final data = await rootBundle.load(path);
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(data.buffer.asUint8List(), (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  // Simplified version of Flutter's paintImage to work on raw Canvas
  static void _paintImage(
    Canvas canvas,
    Rect rect,
    ui.Image image,
    Paint paint,
    BoxFit fit,
  ) {
    Size outputSize = rect.size;
    Size inputSize = Size(image.width.toDouble(), image.height.toDouble());

    FittedSizes fittedSizes = applyBoxFit(fit, inputSize, outputSize);
    Size sourceSize = fittedSizes.source;
    Size destinationSize = fittedSizes.destination;

    // Center the image
    double dx = (outputSize.width - destinationSize.width) / 2.0;
    double dy = (outputSize.height - destinationSize.height) / 2.0;

    Rect sourceRect = Alignment.center.inscribe(
      sourceSize,
      Offset.zero & inputSize,
    );
    Rect destinationRect = Rect.fromLTWH(
      rect.left + dx,
      rect.top + dy,
      destinationSize.width,
      destinationSize.height,
    );

    canvas.drawImageRect(image, sourceRect, destinationRect, paint);
  }
}
