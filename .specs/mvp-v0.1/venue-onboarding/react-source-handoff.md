---
owner: heavy-ui
spec: B02
artifact: react-source-handoff
status: translated
---

# B02 React → Flutter source handoff

| Required field | Current value |
|---|---|
| Source | `/tmp/dobar-lovable-velvet-entry` supplied by the user |
| Immutable source commit SHA | `5975413ccabd6f714af491370892a09c7e651a24`; clean worktree inspected before translation |
| Lovable session URL | Not supplied; local exported repository is the source |
| Entrypoint | `src/pages/VenueRegistration.tsx` |
| Source components | `src/components/venue/VenueShell.tsx`, `IdentitySteps.tsx`, `OptionalSteps.tsx`, `ReviewStep.tsx`, `FlowScreens.tsx` |
| State / copy / themes | `src/lib/venue/model.ts`, `repository.ts`, `copy.ts`, `src/hooks/use-venue-draft.ts`, `src/index.css` |
| Approval scope | User requested execution against this export; no screenshot approval or live-browser visual match is claimed |
| Asset provenance | Registration uses Lucide and user-selected media; unrelated exported onboarding images were not copied |
| Flutter target | [CreateBarPage](../../../fe/lib/features/bars/presentation/pages/create_bar/create_bar_page.dart) → [VenueRegistrationView](../../../fe/lib/features/bars/presentation/pages/create_bar/venue_registration_view.dart) |
| Acceptance evidence | [Validation record](validation-record.md); product verification remains incomplete |

## Translation map

| React source | Flutter implementation |
|---|---|
| VenueShell / progress / save status | Shared AppBar, semantic DobarColors, theme toggle, responsive progress and wrapped footer in VenueRegistrationView |
| StartScreen / creation screens | Authenticated draft list, resume, unknown-result recovery, created/access-refresh retry views |
| FindStep / DetailsStep | Existing Places service plus editable address/coordinates and optional public contact |
| PayoutStep | Optional Brazilian receiving form; encrypted backend persistence, masked summary and explicit replacement |
| PhotosStep | ImagePicker bytes, authenticated multipart upload, progress/retry/removal and durable asset identity |
| HoursStep | Localized weekday labels, time pickers, overnight hint and copy to all days |
| ReviewStep | Section edit cards, invalid-field navigation and persisted AI import intent |
| useVenueDraft / VenueRepository | VenueDraftCubit, domain repository interface and Dio implementation registered through existing GetIt setup |
| Mock access refresh | SessionBloc acknowledged refresh; workspace entry only for the returned bar present in refreshed access |
| copy.ts | `b02_*` keys in English, Portuguese and Spanish ARBs |

## Intentional adaptations

- Exported key `payout` maps explicitly to API/Flutter step `receiving`. Exported short weekday keys map to existing full weekday wire keys. Six-step behavior is retained.
- Reuse Dobar’s existing typography and semantic theme tokens rather than copying the export’s Oswald font/CSS palette literally. Gold buttons always have dark foregrounds.
- Remove the prototype banner, dev scenario switcher, synthetic owner, localStorage mock persistence and simulated success. Production state comes from authenticated routes.
- The export deliberately drops raw partial bank data on browser persistence. Production securely encrypts partial bank inputs server-side, returns only a masked marker and requires replacement/completion/removal before finalization.
- AI import enters the existing MenuReaderPage for the confirmed authorized venue; B03 owns extraction review/publication. No mocked menu result is translated into production.
- Touch outside inputs dismisses focus; scroll drag also dismisses. Device keyboard behavior and screenshot parity still need browser/device verification.

No external Lovable invocation, paid agents, commit, push or deployment was performed.
