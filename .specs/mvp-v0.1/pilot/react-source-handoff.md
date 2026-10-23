---
owner: heavy-ui
spec: B08
artifact: react-source-handoff
status: awaiting-human-export
---

# Staff invitation React → Flutter handoff

The [Lovable prompt](lovable-staff-invitation.md) is ready. No Lovable session, exported source or revision has been supplied by this delivery. Do not fabricate a commit or begin a source-based translation against screenshots alone.

| Field | Current value |
|---|---|
| Source repository URL | Pending human export |
| Immutable commit SHA | Pending human export |
| Exported source directory | Pending human export |
| Lovable session/design reference | Pending human generation |
| Reviewed React state matrix | Pending product review |
| Design assets/license provenance | Pending export review |
| Product approval/evidence reference | Pending review |
| Target spec | B08 |
| Implementation owner | heavy-ui with frontend/backend scoped handoffs |

The human exports/downloads the React repository after generation, supplies its repository URL or local source directory and immutable revision, and records approved state screenshots. The product agent verifies that all required states exist and records any omissions before handing the actual source to the heavy-ui agent. Do not invoke paid model APIs automatically.

## Translation instructions

1. Read [FE guidance](../../../fe/AGENTS.md), existing architecture/workflow references, [B08](../B08-staff-invitation-acceptance.md) and [implementation tasks](implementation-tasks.md). Read the actual exported React components/assets at the recorded revision.
2. Map semantic CSS roles to the existing DobarColors/theme API. Reuse Flutter shared cards/buttons/layouts; preserve browser responsiveness and light/dark behavior. Map copy to localization keys.
3. Implement invitation state through the existing feature/repository/BLoC and dependency-injection patterns. Reuse existing authentication and SessionBloc; navigation must retain a pending invitation through login without treating code possession as identity.
4. Keep generated UI fixture state out of production acceptance decisions. Backend preview/accept responses authorize state changes; update canonical FE/BE contract in the implementation.
5. Run targeted analyzer/widget/BLoC/contract checks. Run code generation only when relevant annotations/localization inputs changed, following FE instructions. Record source revision, changed behavior, command outcomes and screenshots for independent verification.

Translation stays blocked until actual source provenance is available; prompt review and backend contract/security work can proceed independently.
