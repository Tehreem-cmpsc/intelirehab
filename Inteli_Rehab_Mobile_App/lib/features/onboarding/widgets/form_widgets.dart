import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../onboarding_data.dart';

/// A labelled question with an optional helper line and inline error —
/// the mobile equivalent of the portal's `<label>` + input pairs.
class QuestionBlock extends StatelessWidget {
  final String title;
  final String? helper;
  final String? error;
  final Widget child;

  const QuestionBlock({super.key, required this.title, this.helper, this.error, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink)),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(helper!, style: TextStyle(fontSize: 12.5, color: c.muted)),
          ],
          const SizedBox(height: 8),
          child,
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error!, style: TextStyle(fontSize: 12, color: c.alert)),
          ],
        ],
      ),
    );
  }
}

/// Base tappable card with the portal's selected state: tinted fill,
/// teal border, check badge.
class SelectableCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showCheck;

  const SelectableCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.showCheck = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.primaryTint : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? c.primary : c.border, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(padding: padding, child: child),
              if (showCheck && selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.check_circle, size: 18, color: c.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid of option cards (icon + label + caption). Used where each choice
/// deserves a bit of explanation, e.g. activity level.
class OptionGrid extends StatelessWidget {
  final List<Option> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final int columns;

  const OptionGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.columns = 2,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 10.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final o in options)
            SizedBox(
              width: width,
              child: SelectableCard(
                selected: o.value == selected,
                onTap: () => onSelected(o.value),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (o.icon != null) ...[
                      Icon(o.icon, size: 22, color: o.value == selected ? c.primary : c.muted),
                      const SizedBox(height: 10),
                    ],
                    Text(o.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
                    if (o.caption != null) ...[
                      const SizedBox(height: 2),
                      Text(o.caption!, style: TextStyle(fontSize: 12, color: c.muted)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Single-row pill selector, styled like the portal login's role toggle
/// (tinted track, filled teal segment for the active choice).
class SegmentedChoice extends StatelessWidget {
  final List<Option> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const SegmentedChoice({super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.primaryTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: o.value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(o.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                    decoration: BoxDecoration(
                      color: o.value == selected ? c.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      o.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: o.value == selected ? c.onPrimary : c.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Wrap of compact chips for longer option lists.
class ChipChoice extends StatelessWidget {
  final List<Option> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const ChipChoice({super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          Semantics(
            button: true,
            selected: o.value == selected,
            child: Material(
              color: o.value == selected ? c.primaryTint : c.surface,
              shape: StadiumBorder(
                side:
                    BorderSide(color: o.value == selected ? c.primary : c.border, width: o.value == selected ? 1.5 : 1),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onSelected(o.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (o.icon != null) ...[
                        Icon(o.icon, size: 16, color: o.value == selected ? c.primary : c.muted),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        o.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: o.value == selected ? c.primary : c.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Read-only field that opens the date picker.
class DateField extends StatelessWidget {
  final DateTime? value;
  final String hint;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialDate;
  final ValueChanged<DateTime> onChanged;
  final bool hasError;

  const DateField({
    super.key,
    required this.value,
    required this.hint,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.initialDate,
    this.hasError = false,
  });

  static String format(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? initialDate ?? lastDate,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          suffixIcon: const Icon(Icons.expand_more),
          enabledBorder: hasError
              ? OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.alert))
              : null,
        ),
        child: Text(
          value == null ? hint : format(value!),
          style: TextStyle(fontSize: 15, color: value == null ? c.muted.withValues(alpha: 0.7) : c.ink),
        ),
      ),
    );
  }
}

enum BannerTone { info, success, warning }

class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final BannerTone tone;

  const InfoBanner({super.key, required this.icon, required this.text, this.tone = BannerTone.info});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      BannerTone.info => (c.primaryTint, c.primary),
      BannerTone.success => (c.successTint, c.success),
      BannerTone.warning => (c.accent.withValues(alpha: 0.14), c.accent),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: c.ink, height: 1.4))),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const StatusPill({super.key, required this.label, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Plain surface card, as the portal's `.cp-card`.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}
