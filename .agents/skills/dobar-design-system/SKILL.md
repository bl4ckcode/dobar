---
name: dobar-design-system
description: Enforce consistent use of Dobar/Barz design system tokens, components, and themes across every Flutter page and widget.
metadata:
  owner: frontend
---

# dobar-design-system

## Purpose

Enforce consistent use of Dobar/Barz design system tokens, components, and themes across every Flutter page and widget. Apply this skill whenever you encounter a page that does not use the design system, or when adding new UI.

## Core rule

**Never** use raw Flutter widgets (`CircularProgressIndicator`, hard-coded `Colors.white`, `Colors.black`, literal hex colors, `TextStyle(color: ...)` with raw values) in any page. Always use the design system equivalents.

## Key components and where they live

| Use case | Widget / API | Import |
|---|---|---|
| Loading state (page, section, overlay) | `BarzLoadingWidget` | `package:barz/core/presentation/widgets/barz_loading_widget.dart` |
| Theme-aware colors | `context.dobarColors` → `DobarColors` tokens | `package:barz/core/design/tokens/dobar_colors.dart` |
| Text styles | `barzTextTheme.headlineSmall`, `.bodyLarge`, etc. | `package:barz/core/design/design_system.dart` |
| Space tokens | `BarzSpacing.sm/md/lg/xl/xxl` | `package:barz/core/design/design_system.dart` |
| Border radius | `BarzRadii.sm/md/lg` | `package:barz/core/design/design_system.dart` |
| Primary button | `GlowButton(label:, onPressed:)` | `package:barz/core/design/components/glow_button.dart` |
| Bar image (with S3 refresh) | `BarImage` / `BarImageAvatar` | `package:barz/shared/presentation/widget/bar_image.dart` |
| Bar setup checklist balloon | `BarSetupChecklist(barId:)` | `package:barz/shared/presentation/widget/bar_setup_checklist.dart` |

## DobarColors token reference

Access via `final colors = context.dobarColors;` — adapts automatically to light/dark mode.

| Token | Use |
|---|---|
| `colors.background` | Scaffold / page background |
| `colors.surface` | Cards, bottom sheets |
| `colors.surfaceElevated` | Elevated cards, overlays |
| `colors.buttonPrimary` | Primary accent (gold/brand) |
| `colors.buttonOnPrimary` | Text/icons on primary buttons |
| `colors.labelPrimary` | Primary text |
| `colors.labelSecondary` | Secondary / muted text |
| `colors.labelSelected` | Active / selected state |
| `colors.navBackground` | App bar / nav bar background |

## BarzLoadingWidget usage

```dart
// Full page loading
if (isLoading) return const BarzLoadingWidget();

// Custom size or color
BarzLoadingWidget(size: 24, color: colors.buttonPrimary)

// Inside a BlocConsumer builder
builder: (context, state) {
  if (state is SomeLoadingState) return const BarzLoadingWidget();
  ...
}
```

## Pattern: Scaffold with design system

```dart
Scaffold(
  backgroundColor: colors.background,
  appBar: AppBar(
    backgroundColor: colors.navBackground,
    iconTheme: IconThemeData(color: colors.labelPrimary),
    title: Text('Title', style: barzTextTheme.titleMedium?.copyWith(color: colors.labelPrimary)),
  ),
  body: ...,
)
```

## When you encounter a page not using design system

1. Replace `CircularProgressIndicator` → `BarzLoadingWidget()`
2. Replace `Colors.white`/`Colors.black`/raw hex → `colors.background`/`colors.labelPrimary`/etc.
3. Replace raw `TextStyle(...)` → `barzTextTheme.bodyMedium?.copyWith(color: colors.labelSecondary)`
4. Replace `ElevatedButton`/`TextButton` with standard Flutter look → `GlowButton` for primary CTA
5. Add `Scaffold(backgroundColor: colors.background)` if missing

Apply changes incrementally — only to the file you are editing, not globally.
