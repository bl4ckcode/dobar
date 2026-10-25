---
owner: heavy-ui
spec: B08
artifact: react-source-handoff
status: translated
---

# Staff invitation React → Flutter handoff

| Field | Current value |
|---|---|
| Source repository URL | `/Users/carlosalves/Documents/PDev/staff-hub-invitations` (local) |
| Immutable commit SHA | Translation revision still needs author confirmation. Independent inspection on 2026-10-25 found clean local HEAD `55ce9b5ddf04e9baa1200241208cb97e732c7e0f`; this does not establish which revision was translated or approved. |
| Exported source directory | `src/features/invitation/` |
| Lovable session/design reference | Local project; Lovable-generated per `lovable-staff-invitation.md` |
| Reviewed React state matrix | All 14 InvitationViewState variants present in React source |
| Design assets/license provenance | Lovable-generated; no third-party image assets |
| Product approval/evidence reference | Pending product review |
| Target spec | B08 |
| Implementation owner | heavy-ui (DOB-90) |

## Flutter translation map

| React component | Flutter equivalent |
|---|---|
| `InvitationPage` | `StaffInvitationPage` + `_StaffInvitationView` |
| `ManualCodeForm` | `_ManualCodeForm` |
| `InvitationSkeleton` / loading | `_LoadingBody` |
| `GenericInvitationFrame` | `_GenericInvitationFrame` |
| `InvitationCard` | `_InvitationCard` |
| `IdentityPanel` + `SignInOptions` | `_SignedOutBody`, `_SocialButton` |
| `InvitationStatus` | `_StatusBanner` |
| Success state | `_SuccessBody` |
| wrongAccount / unverified / expired / revoked / invalid / loadError | Matching `_*Body` widgets |
| `RoleBadge` | `_RoleBadge` |
| `ThemeToggle` | `_ThemeToggle` |
| `copy.ts` ptBR dictionary | `app_pt.arb` `invitation_*` keys (74 entries) |
| `parseInvitationCode` | `InvitationCubit._parseCode` (same DBR-XXXX-XXXX format, dobar.app host) |

## State coverage

All 14 `InvitationViewState` variants from `types.ts` are handled:
`manualCode`, `loading`, `signedOut`, `ready`, `accepting`, `acceptError`, `accepted`, `alreadyMember`, `wrongAccount`, `unverified`, `expired`, `revoked`, `invalid`, `loadError`.

The human exports/downloads the React repository after generation, supplies its repository URL or local source directory and immutable revision, and records approved state screenshots. The product agent verifies that all required states exist and records any omissions before handing the actual source to the heavy-ui agent. Do not invoke paid model APIs automatically.

## Translation instructions

1. Read [FE guidance](../../../fe/AGENTS.md), existing architecture/workflow references, [B08](../B08-staff-invitation-acceptance.md) and [implementation tasks](implementation-tasks.md). Read the actual exported React components/assets at the recorded revision.
2. Map semantic CSS roles to the existing DobarColors/theme API. Reuse Flutter shared cards/buttons/layouts; preserve browser responsiveness and light/dark behavior. Map copy to localization keys.
3. Implement invitation state through the existing feature/repository/BLoC and dependency-injection patterns. Reuse existing authentication and SessionBloc; navigation must retain a pending invitation through login without treating code possession as identity.
4. Keep generated UI fixture state out of production acceptance decisions. Backend preview/accept responses authorize state changes; update canonical FE/BE contract in the implementation.
5. Run targeted analyzer/widget/BLoC/contract checks. Run code generation only when relevant annotations/localization inputs changed, following FE instructions. Record source revision, changed behavior, command outcomes and screenshots for independent verification.

React source is available and the recorded Flutter translation exists. Translation-revision confirmation and product approval remain incomplete; the observed clean HEAD above does not supply retrospective approval. Independent contract failures and remaining browser/accessibility checks are recorded in the [B08 criterion evidence](validation-checklist.md).
