import 'package:flutter/material.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/core/services/image_refresh_service.dart';
import 'package:barz/core/utils/constant/colors.dart';

/// A specialized image widget for bar images that handles presigned URL expiration
///
/// This widget automatically refreshes expired S3 presigned URLs before displaying
class BarImage extends StatefulWidget {
  final int barId;
  final String? imageUrl;
  final int? imageUrlExpiration;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  final ValueChanged<String>? onImageUrlRefreshed;
  final List<String>? fallbackUrls;

  const BarImage({
    super.key,
    required this.barId,
    this.imageUrl,
    this.imageUrlExpiration,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,

    this.onImageUrlRefreshed,
    this.fallbackUrls,
  });

  @override
  State<BarImage> createState() => _BarImageState();
}

class _BarImageState extends State<BarImage> {
  late ImageRefreshService _imageRefreshService;
  String? _currentUrl;
  bool _isLoading = true;
  bool _hasError = false;

  bool _refreshAttempted = false; // Prevent multiple refresh attempts on error
  int _fallbackIndex =
      -1; // -1 means using main imageUrl, 0+ means using fallbackUrls[index]

  @override
  void initState() {
    super.initState();
    _imageRefreshService = getItInjector<ImageRefreshService>();
    _loadValidUrl();
  }

  @override
  void didUpdateWidget(BarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barId != widget.barId ||
        oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageUrlExpiration != widget.imageUrlExpiration) {
      _loadValidUrl();
    }
  }

  Future<void> _loadValidUrl() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _refreshAttempted = false; // Reset on new load
    });

    try {
      final validUrl = await _imageRefreshService.getValidImageUrl(
        barId: widget.barId,
        currentUrl: widget.imageUrl,
        expirationTimestamp: widget.imageUrlExpiration,
      );

      if (!mounted) return;

      setState(() {
        _currentUrl = validUrl;
        _isLoading = false;
      });

      // Notify parent if URL was refreshed
      if (validUrl != null && validUrl != widget.imageUrl) {
        widget.onImageUrlRefreshed?.call(validUrl);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentUrl = widget.imageUrl;
        _isLoading = false;
      });
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return Uri.tryParse(url)?.isAbsolute ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final defaultPlaceholder = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: barzYellowSoft,
        borderRadius: widget.borderRadius,
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: barzYellowDark,
          ),
        ),
      ),
    );

    final defaultError = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: barzYellowSoft,
        borderRadius: widget.borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store,
            size: (widget.width ?? 50) * 0.4,
            color: barzYellowDark,
          ),
          if (widget.height != null && widget.height! > 60)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Bar',
                style: TextStyle(color: barzYellowDark, fontSize: 12),
              ),
            ),
        ],
      ),
    );

    if (_isLoading) {
      return widget.placeholder ?? defaultPlaceholder;
    }

    if (_hasError || !_isValidUrl(_currentUrl)) {
      return widget.errorWidget ?? defaultError;
    }

    Widget image = Image.network(
      _currentUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder ?? defaultPlaceholder;
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          '[BarImage] Error loading image for bar ${widget.barId}: $error',
        );
        // Try to refresh on error (might be expired URL) - but only once
        // Don't call refresh synchronously in build - use post-frame callback
        if (!_refreshAttempted &&
            !_imageRefreshService.isInCooldown(widget.barId)) {
          _refreshAttempted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _imageRefreshService.forceRefresh(widget.barId).then((newUrl) {
              if (newUrl != null && mounted) {
                // If we got a new URL and it's different from current, use it
                if (newUrl != _currentUrl) {
                  setState(() => _currentUrl = newUrl);
                  return;
                }
              }

              // If refresh failed or returned same URL, try fallbacks
              if (mounted &&
                  widget.fallbackUrls != null &&
                  widget.fallbackUrls!.isNotEmpty) {
                if (_fallbackIndex < widget.fallbackUrls!.length - 1) {
                  setState(() {
                    _fallbackIndex++;
                    _currentUrl = widget.fallbackUrls![_fallbackIndex];
                  });
                  return;
                }
              }

              if (mounted) {
                // Refresh failed or returned null, show error state
                setState(() => _hasError = true);
              }
            });
          });
        }

        // If we are already traversing fallbacks (refreshAttempted is true)
        if (_refreshAttempted &&
            widget.fallbackUrls != null &&
            _fallbackIndex < widget.fallbackUrls!.length - 1) {
          // Queue next fallback attempt
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _fallbackIndex++;
                _currentUrl = widget.fallbackUrls![_fallbackIndex];
              });
            }
          });
        }

        return widget.errorWidget ?? defaultError;
      },
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }
}

/// A circular avatar version of BarImage
class BarImageAvatar extends StatefulWidget {
  final int barId;
  final String? imageUrl;
  final int? imageUrlExpiration;
  final double radius;
  final Widget? fallbackIcon;
  final Color? backgroundColor;

  const BarImageAvatar({
    super.key,
    required this.barId,
    this.imageUrl,
    this.imageUrlExpiration,
    this.radius = 20,
    this.fallbackIcon,
    this.backgroundColor,
  });

  @override
  State<BarImageAvatar> createState() => _BarImageAvatarState();
}

class _BarImageAvatarState extends State<BarImageAvatar> {
  late ImageRefreshService _imageRefreshService;
  String? _currentUrl;
  bool _isLoading = true;
  bool _refreshAttempted = false; // Prevent multiple refresh attempts on error

  @override
  void initState() {
    super.initState();
    _imageRefreshService = getItInjector<ImageRefreshService>();
    _loadValidUrl();
  }

  @override
  void didUpdateWidget(BarImageAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barId != widget.barId ||
        oldWidget.imageUrl != widget.imageUrl) {
      _loadValidUrl();
    }
  }

  Future<void> _loadValidUrl() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _refreshAttempted = false; // Reset on new load
    });

    try {
      final validUrl = await _imageRefreshService.getValidImageUrl(
        barId: widget.barId,
        currentUrl: widget.imageUrl,
        expirationTimestamp: widget.imageUrlExpiration,
      );

      if (!mounted) return;

      setState(() {
        _currentUrl = validUrl;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentUrl = widget.imageUrl;
        _isLoading = false;
      });
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return Uri.tryParse(url)?.isAbsolute ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? barzYellowSoft;
    final fallback =
        widget.fallbackIcon ??
        Icon(Icons.store, size: widget.radius, color: barzYellowDark);

    if (_isLoading) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bgColor,
        child: SizedBox(
          width: widget.radius,
          height: widget.radius,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: barzYellowDark,
          ),
        ),
      );
    }

    if (!_isValidUrl(_currentUrl)) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bgColor,
        child: fallback,
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: bgColor,
      backgroundImage: NetworkImage(_currentUrl!),
      onBackgroundImageError: (exception, stackTrace) {
        debugPrint('[BarImageAvatar] Error loading image: $exception');
        // Try to refresh on error - but only once and with cooldown check
        if (!_refreshAttempted &&
            !_imageRefreshService.isInCooldown(widget.barId)) {
          _refreshAttempted = true;
          _imageRefreshService.forceRefresh(widget.barId).then((newUrl) {
            if (newUrl != null && mounted) {
              setState(() => _currentUrl = newUrl);
            }
          });
        }
      },
      child: null,
    );
  }
}
