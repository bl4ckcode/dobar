import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:barz/features/home/domain/home_toolbar.dart';
import 'package:barz/l10n/app_localizations.dart';
import '../design_system.dart';

/// Home toolbar: greeting / promo count / nearby check-in prompt, the
/// notifications button (always visible; badge only above zero, capped at
/// `99+`) and the persisted light/dark toggle. Lives in normal layout flow so
/// permission messages and large text never overlap content.
class HomeConnectedHeader extends StatelessWidget {
  final HomeToolbarContent content;
  final int unreadNotifications;
  final VoidCallback? onNearbyTap;
  final VoidCallback? onNotificationTap;
  final bool isDark;
  final VoidCallback? onToggleTheme;

  const HomeConnectedHeader({
    super.key,
    this.content = const PlainGreetingToolbar(),
    this.unreadNotifications = 0,
    this.onNearbyTap,
    this.onNotificationTap,
    this.isDark = false,
    this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final l10n = AppLocalizations.of(context)!;
    final badge = notificationBadgeLabel(unreadNotifications);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _buildLeading(context, colors, l10n)),
          const SizedBox(width: 10),
          _RoundButton(
            semanticLabel: badge == null
                ? l10n.home_notifications_none
                : l10n.home_notifications(badge),
            onTap: onNotificationTap,
            colors: colors,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(LucideIcons.bell, color: colors.labelPrimary, size: 20),
                if (badge != null)
                  Positioned(
                    right: -6,
                    top: -8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.background, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RoundButton(
            semanticLabel: isDark
                ? l10n.home_theme_to_light
                : l10n.home_theme_to_dark,
            onTap: onToggleTheme,
            colors: colors,
            child: Icon(
              isDark ? LucideIcons.sun : LucideIcons.moon,
              color: colors.labelPrimary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeading(
    BuildContext context,
    DobarColors colors,
    AppLocalizations l10n,
  ) {
    final c = content;
    if (c is NearbyVenueToolbar) return _nearby(c, colors, l10n);
    final name = switch (c) {
      PromoGreetingToolbar(:final name) => name,
      PlainGreetingToolbar(:final name) => name,
      _ => null,
    };
    final text = switch (c) {
      PromoGreetingToolbar(:final count) =>
        name == null
            ? l10n.home_greeting_promos_anon(count)
            : l10n.home_greeting_promos(name, count),
      _ =>
        name == null
            ? l10n.home_greeting_plain
            : '${l10n.home_greeting_plain}, $name',
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.labelPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _nearby(
    NearbyVenueToolbar c,
    DobarColors colors,
    AppLocalizations l10n,
  ) {
    return Semantics(
      button: true,
      label: l10n.home_nearby_venue(c.venue.name),
      excludeSemantics: true,
      child: InkWell(
        onTap: onNearbyTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.surfaceElevated, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: barzGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.map_pin,
                  color: barzDark,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.home_nearby_prefix,
                      style: TextStyle(
                        color: colors.labelSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      c.venue.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.labelPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevron_right,
                color: colors.labelSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final String semanticLabel;
  final VoidCallback? onTap;
  final DobarColors colors;
  final Widget child;

  const _RoundButton({
    required this.semanticLabel,
    required this.onTap,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border: Border.all(color: colors.surfaceElevated, width: 1.5),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
