import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../progress_models.dart';

/// Icon + name only — no numeric score competing with the ROM chart
/// above it (Rule 8: recovery data outranks badges).
class BadgeTile extends StatelessWidget {
  final EarnedBadge badge;
  const BadgeTile({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.primaryTint, shape: BoxShape.circle),
            child: badge.iconUrl == null
                ? Icon(Icons.emoji_events_outlined, color: c.primary, size: 22)
                : ClipOval(
                    child: Image.network(
                      badge.iconUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.emoji_events_outlined, color: c.primary, size: 22),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.ink),
          ),
        ],
      ),
    );
  }
}
