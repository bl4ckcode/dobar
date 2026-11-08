import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/design/components/glow_button.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class ProfileFrame extends StatelessWidget {
  const ProfileFrame({
    super.key,
    required this.title,
    required this.children,
    this.root = false,
    this.actions,
  });
  final String title;
  final List<Widget> children;
  final bool root;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !root,
        backgroundColor: colors.background,
        foregroundColor: colors.labelPrimary,
        surfaceTintColor: colors.background,
        centerTitle: false,
        elevation: 0,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.labelPrimary,
          ),
        ),
        actions: actions,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                BarzSpacing.lg,
                BarzSpacing.lg,
                BarzSpacing.lg,
                root ? 120 : BarzSpacing.xl,
              ),
              children: [
                for (final child in children) ...[
                  child,
                  const SizedBox(height: BarzSpacing.xl),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileGroup extends StatelessWidget {
  const ProfileGroup({
    super.key,
    this.title,
    this.accent = false,
    required this.children,
  });
  final String? title;
  final bool accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final border = Theme.of(context).dividerColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(
                left: BarzSpacing.xs,
                bottom: BarzSpacing.sm,
              ),
              child: Text(
                title!.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.labelSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
            ),
          ),
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BarzRadii.xl),
            side: BorderSide(
              color: accent
                  ? colors.buttonPrimary.withValues(alpha: .6)
                  : border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileRow extends StatelessWidget {
  const ProfileRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.accent = false,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool accent;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.dobarColors;
    final ink = destructive
        ? Theme.of(context).colorScheme.error
        : colors.labelPrimary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: accent ? 80 : 56),
        child: Padding(
          padding: const EdgeInsets.all(BarzSpacing.lg),
          child: Row(
            children: [
              if (accent)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.buttonPrimary,
                    borderRadius: BorderRadius.circular(BarzRadii.lg),
                  ),
                  child: Icon(icon, size: 22, color: colors.buttonOnPrimary),
                )
              else
                Icon(
                  icon,
                  size: 20,
                  color: destructive ? ink : colors.labelSecondary,
                ),
              const SizedBox(width: BarzSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.labelSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (!destructive) ...[
                const SizedBox(width: BarzSpacing.sm),
                Icon(
                  LucideIcons.chevron_right,
                  size: 18,
                  color: colors.labelSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmProfileAction(
  BuildContext context,
  String title,
  String body,
) async {
  final l10n = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(title),
            ),
          ],
        ),
      ) ??
      false;
}

/// Gives the shared branded action keyboard and screen-reader semantics.
class ProfilePrimaryButton extends StatelessWidget {
  const ProfilePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: FocusableActionDetector(
        enabled: enabled,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (enabled) onPressed!();
              return null;
            },
          ),
        },
        child: Builder(
          builder: (context) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BarzRadii.md),
              border: Focus.of(context).hasFocus
                  ? Border.all(
                      color: context.dobarColors.labelPrimary,
                      width: 2,
                    )
                  : null,
            ),
            child: GlowButton(
              wrapLabel: true,
              label: label,
              enabled: enabled,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}
