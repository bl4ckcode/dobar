---
name: dobar-lovable-prompt
description: Turn an approved Dobar journey spec into a Lovable React UI prompt and a traceable Flutter translation handoff following existing design conventions.
metadata:
  owner: product
---

# dobar-lovable-prompt

## Inputs and context

Read the spec, [prompt collection](../../../fe/.docs/lovable_stitch_prompts.md), [frontend instructions](../../../fe/AGENTS.md), [semantic tokens](../../../fe/lib/core/design/tokens/dobar_colors.dart), and [design concepts](../../../fe/docs/SYSTEM_DESIGN_CONCEPTS.md). Treat older prompts as visual references; their Flutter or React Native technical directions do not override this workflow's React UI output.

## Procedure and outputs

- Use the collection's CONTEXT, OVERALL VIBE, PAGE STRUCTURE, INTERACTIONS, ANIMATIONS, and TECHNICAL NOTE pattern where useful. Request an exportable React UI, with clear mocked states and no invented backend success.
- Describe Industrial Modern styling, gold accents, Lucide icons, Portuguese copy, light/dark themes, responsive browser layouts, keyboard/focus/screen-reader behavior, and reduced-motion support. Reuse semantic color intent when the Flutter implementation follows.
- Map each screen/state to spec acceptance criteria. For B08 include login-resume, verified contact match, wrong account, expired/revoked/used invitations, retry/loading/error/success, duplicate acceptance, and workspace entry only after acceptance.
- Deliver the prompt, state/criterion mapping, and human handoff: generate in Lovable, export React repository, record URL/path and exact revision, then assign translation using dobar-react-to-flutter.

## Boundaries, checks, and escalation

Do not invoke Lovable or claim exported source exists without evidence. Do not implement payment collection, acceptance authorization, or account matching in the design mock. Compare prompt coverage against the spec and existing brand; surface contradictory legacy prompt behavior to product. The output is a reviewable prompt package, not a validated application screen.
