import 'package:flutter/material.dart';

/// A network image widget with proper error handling and fallback
///
/// Use this instead of Image.network or NetworkImage directly to handle:
/// - Corrupted images from S3
/// - Invalid URLs
/// - Network errors
/// - Loading states
class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const SafeNetworkImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return Uri.tryParse(url)?.isAbsolute ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final defaultPlaceholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.image_outlined,
        size: (width ?? 50) * 0.4,
        color: Colors.grey[500],
      ),
    );

    final defaultError = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_bar,
            size: (width ?? 50) * 0.4,
            color: Colors.grey[600],
          ),
          if (height != null && height! > 60)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Bar',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
        ],
      ),
    );

    if (imageUrl != null && imageUrl!.startsWith('marketing_mockups/')) {
      Widget image = Image.asset(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? defaultError;
        },
      );
      if (borderRadius != null) {
        image = ClipRRect(borderRadius: borderRadius!, child: image);
      }
      return image;
    }

    if (!_isValidUrl(imageUrl)) {
      return errorWidget ?? defaultError;
    }

    Widget image = Image.network(
      imageUrl!,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? defaultPlaceholder;
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[SafeNetworkImage] Error loading image: \$error');
        return errorWidget ?? defaultError;
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

/// A circular avatar version of SafeNetworkImage
class SafeNetworkAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? fallbackIcon;
  final Color? backgroundColor;

  const SafeNetworkAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.fallbackIcon,
    this.backgroundColor,
  });

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return Uri.tryParse(url)?.isAbsolute ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValidUrl(imageUrl)) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[300],
        child: fallbackIcon ?? Icon(Icons.local_bar, size: radius),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[300],
      backgroundImage: NetworkImage(imageUrl!),
      onBackgroundImageError: (exception, stackTrace) {
        debugPrint('[SafeNetworkAvatar] Error loading image: \$exception');
      },
      child: fallbackIcon, // Shows when image fails
    );
  }
}
