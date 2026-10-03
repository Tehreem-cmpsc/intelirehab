import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

/// The short looping illustration of an exercise (exercises.media_url).
///
/// media_url is either a path relative to the app ('exercises/hammer-curl.webp',
/// bundled under assets/ so it works offline) or a full https:// URL. Anything
/// else is ignored - the value comes from a table physios can edit.
///
/// Only images (including animated WebP/GIF) are shown here. A 'video' entry
/// falls back to the placeholder until the app has a video player.
///
/// Never blocks a screen: no media, a video, or a file that fails to load all
/// show a quiet placeholder instead.
class ExerciseMedia extends StatelessWidget {
  final String? mediaUrl;
  final String mediaType;
  final String name;

  /// Fixed square size (thumbnails). Null = fill the width at [aspectRatio].
  final double? size;
  final double aspectRatio;
  final double radius;

  const ExerciseMedia({
    super.key,
    required this.mediaUrl,
    required this.name,
    this.mediaType = 'image',
    this.size,
    this.aspectRatio = 16 / 10,
    this.radius = 14,
  });

  /// The illustrations are baked on this light tint, so letterboxing matches in either theme.
  static const _panel = Color(0xFFE4F1F0);

  /// What to load for [mediaUrl], or null if there's nothing safe to show.
  static ImageProvider? providerFor(String? mediaUrl, {String mediaType = 'image'}) {
    if (mediaType != 'image') return null;
    final url = mediaUrl?.trim();
    if (url == null || url.isEmpty) return null;
    if (url.toLowerCase().startsWith('https://')) return NetworkImage(url);
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(url);
    if (hasScheme || url.startsWith('//') || url.contains('..')) return null;
    return AssetImage('assets/${url.replaceFirst(RegExp(r'^/+'), '')}');
  }

  @override
  Widget build(BuildContext context) {
    final provider = providerFor(mediaUrl, mediaType: mediaType);
    final thumb = size != null;

    Widget placeholder() => Container(
          color: _panel,
          alignment: Alignment.center,
          child: Icon(Icons.accessibility_new, size: thumb ? size! * 0.5 : 56, color: context.colors.primary),
        );

    Widget content = provider == null
        ? placeholder()
        : Image(
            image: provider,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            // Decode thumbnails at their display size; they're animated, so this matters.
            width: size,
            height: size,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => placeholder(),
          );

    // Respect the system "reduce motion" setting: a stopped ticker freezes the animation.
    content = TickerMode(enabled: !MediaQuery.disableAnimationsOf(context), child: content);

    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(color: _panel, child: content),
    );

    return Semantics(
      image: true,
      label: provider == null ? null : 'Animated illustration of how to do $name.',
      excludeSemantics: true,
      child: thumb
          ? SizedBox.square(dimension: size, child: framed)
          : AspectRatio(aspectRatio: aspectRatio, child: framed),
    );
  }
}

/// The list-row version: the illustration when there is one, otherwise the
/// plain icon the list always used.
class ExerciseThumb extends StatelessWidget {
  final String? mediaUrl;
  final String mediaType;
  final String name;
  final double size;

  const ExerciseThumb({super.key, required this.mediaUrl, required this.name, this.mediaType = 'image', this.size = 56});

  @override
  Widget build(BuildContext context) {
    if (ExerciseMedia.providerFor(mediaUrl, mediaType: mediaType) == null) {
      return IconBadge(Icons.accessibility_new, size: size);
    }
    return ExerciseMedia(mediaUrl: mediaUrl, mediaType: mediaType, name: name, size: size, radius: 12);
  }
}
