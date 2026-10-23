---
name: dobar-react-to-flutter
description: Translate a versioned exported React UI into Dobar Flutter widgets, states, navigation, localization, and existing architecture while retaining approved UX.
metadata:
  owner: heavy-ui
---

# dobar-react-to-flutter

## Inputs and context

Require the approved spec/prompt and the actual exported repository path plus exact revision. Read [frontend instructions](../../../fe/AGENTS.md), [architecture](../../../fe/docs/agents/architecture.md), [workflow](../../../fe/docs/agents/development_workflow.md), and the relevant existing Flutter screen. Use dobar-frontend for implementation conventions.

## Procedure and outputs

- Inspect the React component tree, assets, tokens, responsive rules, and interaction states; record the revision and which source components map to Flutter surfaces.
- Reuse existing Flutter components and semantic `context.dobarColors`/theme tokens. Translate layout and behavior rather than copying DOM/Tailwind structure literally.
- Connect interactions through existing BLoC/Cubit, repository, GetIt, and GoRouter patterns. Preserve deep-link/login-resume context; keep mock React data out of production repositories.
- Localize strings with existing ARB/AppLocalizations, including pt_BR copy. Preserve browser resizing, keyboard navigation, focus order, touch targets, light/dark themes, and reduced motion.
- Keep stateful business logic out of paint/layout widgets. Extract reusable components where a real repeated interaction exists, without reorganizing unrelated feature code.

## Boundaries, checks, and escalation

If the exported source/revision is missing, deliver the mapping checklist and mark translation blocked; do not invent a source export. Run code generation only for modified annotated models, then relevant Flutter analysis and widget/state tests. Compare key screen states visually at narrow and wide widths and in both themes. Report observed matches, deviations, and device/browser evidence still missing. Return contract gaps to the planner and product ambiguity to product.
