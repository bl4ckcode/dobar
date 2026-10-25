---
name: dobar-frontend
description: Implement scoped Dobar Flutter features with existing BLoC/Cubit, repositories, GetIt, GoRouter, localization, semantic themes, and meaningful UI checks.
metadata:
  owner: frontend
---

# dobar-frontend

## Inputs and context

Read the spec and handoff, [FE instructions](../../../fe/AGENTS.md), [architecture](../../../fe/docs/agents/architecture.md), [development workflow](../../../fe/docs/agents/development_workflow.md), and [FE/BE contract](../../../docs/FE_BE_COMMUNICATION.md). Inspect the existing feature before choosing whether it belongs under `lib/features` or the existing `lib/ui` surface.

## Procedure and outputs

- Keep presentation in widgets/BLoC/Cubit, domain behavior behind repository interfaces/use cases, and networking/storage in data implementations. Register dependencies through existing `lib/shared/app_injections.dart` patterns.
- Extend existing GoRouter guards/deep-link behavior; retain pending invitation context across login and refresh. Client gating never replaces backend authorization.
- Use `AppLocalizations` and existing `lib/l10n/*.arb` resources; use semantic DobarColors/theme tokens for labels, surfaces, and actions. Test Portuguese copy, narrow/wide layouts, and both themes.
- Inspect actual request/response models. Maintain compatibility, distinguish transport/provider/validation errors, and update the canonical contract when an approved interface changes.
- For payment UI, use provider tokens and backend-confirmed state. Never add secret provider keys, raw-card logging, client-authoritative charge amounts, or redirect-only success.

## Boundaries, checks, and escalation

From `fe`, run relevant `flutter analyze` and `flutter test` targets. Run `dart run build_runner build --delete-conflicting-outputs` only when changed generated-model inputs require it, and inspect generated diffs. Add regression coverage for meaningful state/behavior changes; avoid tests that merely repeat layout constants. Deliver a scoped patch and exact evidence; report missing native-device/browser checks separately. Escalate API gaps through the planner instead of inventing backend support.

## Communication handoff

When this task changes an integration boundary, use [dobar-communication-docs](../dobar-communication-docs/SKILL.md). Replace the latest entry for the sending area, retain the other side's entry, update the date and remove superseded text. Git/Linear carry history; do not append a change log or a full API catalog.
