import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:veriframe_app/service/user_profile_cache.dart';
import 'package:veriframe_app/utils/theme.dart';

/// Commercial-grade avatar widget with zero-flicker preloading, aggressive
/// caching, smooth fade-in only when uncached, and instant fallback to `assets/images/empty.jpg`.
class SafeAvatarWidget extends StatefulWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? fallbackName;
  final double radius;
  final VoidCallback? onTap;
  final Border? border;

  const SafeAvatarWidget({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.fallbackName,
    this.radius = 20,
    this.onTap,
    this.border,
  });

  @override
  State<SafeAvatarWidget> createState() => _SafeAvatarWidgetState();
}

class _SafeAvatarWidgetState extends State<SafeAvatarWidget> {
  bool _hasError = false;

  @override
  void didUpdateWidget(covariant SafeAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.imageBytes != widget.imageBytes) {
      if (_hasError) setState(() => _hasError = false);
    }
  }

  Widget _buildEmptyFallback() {
    return Image.asset(
      'assets/images/empty.jpg',
      fit: BoxFit.cover,
      width: widget.radius * 2,
      height: widget.radius * 2,
      errorBuilder: (_, __, ___) => _buildLetterFallback(),
    );
  }

  Widget _buildLetterFallback() {
    final name = widget.fallbackName ?? UserProfileCache.instance.userName;
    final initial = (name.trim().isNotEmpty) ? name.trim()[0].toUpperCase() : 'U';
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      color: VFColors.blue600,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.radius * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildContainer(child: _buildEmptyFallback());
    }

    final bytes = widget.imageBytes ?? UserProfileCache.instance.cachedImageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return _buildContainer(
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: widget.radius * 2,
          height: widget.radius * 2,
          errorBuilder: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasError = true);
            });
            return _buildEmptyFallback();
          },
        ),
      );
    }

    final url = widget.imageUrl ?? UserProfileCache.instance.cachedImageUrl;

    if (url != null && url.startsWith('data:image')) {
      try {
        final b64 = url.split(',')[1];
        final bytes = base64Decode(b64);
        return _buildContainer(
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: widget.radius * 2,
            height: widget.radius * 2,
            errorBuilder: (_, __, ___) => _buildEmptyFallback(),
          ),
        );
      } catch (_) {
        return _buildContainer(child: _buildEmptyFallback());
      }
    }

    if (url != null && url.trim().isNotEmpty) {
      return _buildContainer(
        child: CachedNetworkImage(
          imageUrl: url.trim(),
          fit: BoxFit.cover,
          width: widget.radius * 2,
          height: widget.radius * 2,
          placeholder: (_, __) => _buildEmptyFallback(),
          errorWidget: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasError = true);
            });
            return _buildEmptyFallback();
          },
        ),
      );
    }

    return _buildContainer(child: _buildEmptyFallback());
  }

  Widget _buildContainer({required Widget child}) {
    final size = widget.radius * 2;
    Widget avatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: child,
      ),
    );

    if (widget.border != null) {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: widget.border,
        ),
        child: avatar,
      );
    }

    if (widget.onTap != null) {
      avatar = GestureDetector(
        onTap: widget.onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
