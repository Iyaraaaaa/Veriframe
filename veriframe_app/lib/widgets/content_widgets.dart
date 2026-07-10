// lib/widgets/content_widgets.dart
import 'package:flutter/material.dart';
import 'package:veriframe_app/utils/theme.dart';

/// An uppercase accent-coloured section label used as an elegant header.
class SectionLabel extends StatelessWidget {
  final String label;
  const SectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ],
    );
  }
}

/// A themed surface card with a subtle border, used consistently everywhere.
class ThemedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;

  const ThemedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = accent != null
        ? BorderSide(color: accent!, width: 1.5)
        : BorderSide(color: c.border);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.color, width: border.width),
      ),
      child: child,
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      );
    }
    return card;
  }
}

/// A titled paragraph block: a heading followed by body text.
class InfoBlock extends StatelessWidget {
  final String title;
  final String body;
  final TextStyle? titleStyle;
  final TextStyle? bodyStyle;

  const InfoBlock({
    super.key,
    required this.title,
    required this.body,
    this.titleStyle,
    this.bodyStyle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: titleStyle ??
              TextStyle(
                color: c.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: bodyStyle ??
              TextStyle(
                color: c.textMuted,
                fontSize: 14,
                height: 1.6,
              ),
        ),
      ],
    );
  }
}

/// A feature/value card with an icon badge, title and description.
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ThemedCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A smooth horizontal divider styled from the active theme.
class ThemedDivider extends StatelessWidget {
  const ThemedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Divider(color: c.divider, thickness: 1, height: 1);
  }
}

/// A consistent, elegant page header used across info screens.
///
/// Renders an accent icon badge, an optional uppercase tagline, a large
/// bold title and an optional supporting subtitle. Designed to give the
/// Privacy, About and Contact screens a unified, professional opening.
class PageHeader extends StatelessWidget {
  final IconData icon;
  final String? tagline;
  final String title;
  final String? subtitle;
  final double iconSize;

  const PageHeader({
    super.key,
    required this.icon,
    this.tagline,
    required this.title,
    this.subtitle,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: c.accent.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(icon, color: c.accent, size: iconSize),
        ),
        if (tagline != null) ...[
          const SizedBox(height: 16),
          Text(
            tagline!.toUpperCase(),
            style: TextStyle(
              color: c.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: c.text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: TextStyle(
              color: c.textMuted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}

/// A single bullet point with a subtle accent marker, used in lists.
class BulletPoint extends StatelessWidget {
  final String text;
  final double iconSize;

  const BulletPoint(this.text, {super.key, this.iconSize = 6});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(iconSize / 2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: c.textMuted,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill/chip used for tags and categories.
class ThemedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const ThemedChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = selected ? c.accent : c.surfaceVariant;
    final fg = selected ? c.onAccent : c.textMuted;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? c.accent : c.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    return onTap != null
        ? InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: chip)
        : chip;
  }
}
