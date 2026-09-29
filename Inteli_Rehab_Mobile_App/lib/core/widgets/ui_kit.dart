import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dashed_ring.dart';

/// Shared building blocks for the patient dashboard (Home, Exercises,
/// Progress, Profile), so every tab reads as one product: soft cards,
/// tinted icon badges, one stat-tile shape, one empty/error pattern and a
/// thumb-zone bottom action bar. Colours all come from AppColors — the
/// palette itself is unchanged.

/// Card surface: a soft shadow in light mode, a hairline border in dark
/// (shadows barely read on dark backgrounds).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final String? semanticLabel;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(18),
        border: dark ? Border.all(color: c.border) : null,
        boxShadow: dark
            ? null
            : [BoxShadow(color: c.primaryDeep.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (semanticLabel == null) return card;
    return Semantics(label: semanticLabel, button: onTap != null, child: card);
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink, letterSpacing: -0.1),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A tinted rounded square holding an icon — the list-row / stat marker.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const IconBadge(this.icon, {super.key, this.color, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, color: fg, size: size * 0.5),
    );
  }
}

/// Icon + value + label, never a bare number (Progress Rule / Rule 9).
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon, color: color, size: 34),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.ink, height: 1)),
            ),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

class PillTag extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const PillTag(this.text, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// The teal gradient header the onboarding and login screens already use,
/// reused for each tab's top section so the dashboard matches them.
class HeroHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const HeroHeader({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28)});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.headerStart, c.headerEnd],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(right: -80, top: -70, child: ExcludeSemantics(child: DashedRing(size: 230, spin: true))),
          SafeArea(bottom: false, child: Padding(padding: padding, child: child)),
        ],
      ),
    );
  }
}

/// Centered icon + message + optional action — no dead ends (Rule 16).
class MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const MessageState({
    super.key,
    required this.icon,
    required this.title,
    this.text,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon, color: isError ? c.alert : c.primary, size: 64),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink, height: 1.35),
            ),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(text!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.4)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Primary actions pinned to the bottom, full-width — the thumb zone
/// (Rule 21). Use as a Scaffold's bottomNavigationBar.
class BottomActionBar extends StatelessWidget {
  final List<Widget> children;
  const BottomActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String initialsOf(String name) {
  final parts = name.replaceFirst(RegExp(r'^Dr\.?\s*'), '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
