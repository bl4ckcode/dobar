---
owner: product
spec: B02
artifact: lovable-prompt
status: ready-for-generation
---

# B02 venue onboarding — Lovable prompt

Copy the brief below into Lovable. This is a design package for [B02](../B02-venue-onboarding.md), not evidence of a working application. See the [implementation plan](implementation-plan.md) and [export handoff](react-source-handoff.md).

## Copyable prompt

Build an exportable React + TypeScript UI prototype for Dobar’s resumable business venue registration. Refine the existing six-step workflow instead of replacing it with one long form. The result will be translated into Flutter after review.

**CONTEXT**

The user is an authenticated business owner registering a bar in Belo Horizonte, Brazil. Default copy is Brazilian Portuguese; use BRL wherever money is displayed, and America/Sao_Paulo for operating hours. This flow collects venue identity and optional contact information, receiving-account details, photos and hours, and offers entry into AI menu import. It must save progress and resume later. It does not sell a subscription, collect card payments, or verify a receiving account.

Use the supplied screenshot as evidence of the existing structure and readability defect: white input text on a pale yellow field is unreadable. Correct the color pairing throughout the entire workflow. Keep the six steps recognizable: Encontrar bar → Dados → Recebimentos → Fotos → Horários → Revisão. Add AI menu import as an optional branch from Revisão and the completion screen, without introducing a seventh mandatory step.

**OVERALL VIBE**

Industrial Modern: professional, calm, premium hospitality. Space Grotesk headings, clean system body font, restrained rounded cards and pill actions, generous but practical spacing. Use Lucide icons consistently: Store, MapPin, Phone, Mail, Landmark, ImagePlus, Clock, ScanText, Save, Check, AlertCircle, Sun and Moon. No decorative typewriter titles or continuous glowing effects.

Implement semantic CSS tokens, with separate light/dark values corresponding to Dobar’s background, surface, surfaceElevated, labelPrimary, labelSecondary, labelSelected, labelOnSelected, buttonPrimary and buttonOnPrimary roles. Use brand gold #FFDE59; dark background #0A0A0A; dark surfaces #121212 / #1A1A1A; light background #FFFBF5; light surfaces #FFFFFF / #F5F5F5; primary light-theme text #1A1A2E. A light input may use #FFF8E1 only with dark text. Dark-theme inputs should use dark surfaces and light text. Gold-filled controls always use dark text/icons in both themes. Derive readable border, hint, error and focus colors per theme rather than applying global white text to every input. Never use white text on gold or cream. Target normal-text contrast ≥4.5:1 and large-text/UI-boundary contrast ≥3:1; verify actual rendered pairs including hints and errors.

**PAGE STRUCTURE**

Shared shell on EVERY page/state, including resume, error, success and import branch:

- Header with close/back at left, “Cadastrar estabelecimento”, and a light/dark button at the TOP RIGHT. Its accessible name describes the action: “Ativar tema escuro” / “Ativar tema claro”. Initialize from system preference, remember an explicit choice, and preserve form data, current step and scroll on toggle. The theme button remains present in dialogs and narrow layouts through the shared shell.
- Desktop: centered form around 720px wide inside a generous browser layout, six-step progress indicator, visible save status and footer. Mobile: full-width fluid cards, 16px side padding, compact “Etapa 2 de 6 · Dados” plus an accessible step list; never squeeze six long labels into one row.
- Always distinguish “Alterações não salvas”, “Salvando…”, “Rascunho salvo às 14:32”, and “Não foi possível salvar”. Provide “Salvar e sair” and an explicit retry. Show “Rascunho” separately from any completed-venue status.
- Footer: “Voltar”, “Continuar” and optional “Agora não” where applicable; final action “Criar estabelecimento”. Keep actions reachable with mobile keyboard open, safe-area padding, and a scrolling form that never sits behind the footer.

Screens:

1. **Start / resume:** loading, no drafts, and saved-draft list with venue name or “Estabelecimento sem nome”, update time and next incomplete step. “Retomar cadastro” and “Iniciar outro cadastro”. A draft is never shown as an active business. Include session-expired, load failure/retry, unavailable draft and wrong-account/access-denied fixtures; do not reveal another owner’s fields.
2. **Encontrar bar:** search by venue/address with loading, matches, no results and lookup failure. Allow “Cadastrar manualmente” and editable address/map-location confirmation when lookup is unavailable. Prefill selected results but allow corrections. Do not fake a real Places connection or default missing coordinates to 0,0.
3. **Dados:** required venue name and address/location confirmation, country fixed to Brasil in this MVP preview; optional public phone/email grouped under “Contato (opcional)”. Business identifier is optional here; show validation if supplied, not a compulsory receiving-account gate. Clearly mark required versus optional fields. Save incomplete text without requiring the step to be valid; validate required identity before advancing/finalizing. Include inline invalid-value states and a summary linking to affected inputs. Do not add unrelated category, marketing, subscription or location-method configuration.
4. **Recebimentos (opcional):** explain “Configure agora ou depois nas configurações”. Mock either Pix key/type or Brazilian bank/branch/account/type and holder fields; no real banking/provider calls. “Agora não” must work. Partial invalid details can remain in a draft, but must be completed or explicitly removed before finalization. On resume/review show only a masked account/Pix summary, “Dados salvos · verificação pendente”, and “Substituir dados”. Never prefill masked characters as a real input value or label saving as verification. No PAN/CVV or payment collection.
5. **Fotos (opcional):** logo, cover and gallery; upload picker/drop zone, preview, progress, remove, per-file failure/retry and unsupported-file state. Mobile uses a picker rather than requiring drag/drop. Clearly distinguish selected locally, uploading and saved remotely. A failed upload retains the form and offers retry, remove or skip; local file paths cannot be represented as durable saved media. Use synthetic fixtures, with a visible note that uploads are simulated.
6. **Horários (opcional):** Portuguese weekday labels, open/closed per day, time inputs, copy-to-other-days and an example overnight interval (18:00–02:00, closes next day). Offer “Configurar depois”. Distinguish not configured from explicitly closed all week. Preserve edits on back/next/theme changes.
7. **Revisão:** editable cards for each section; mark omissions “Configurar depois”. Show missing required fields, invalid supplied optional values, pending uploads and save status. Include optional “Importar cardápio com IA” entry with “Importar depois”. If chosen before creation, save that intent in the draft and explain “Crie o estabelecimento para continuar a importação”; after successful creation/access refresh, open the import branch for the returned venue. No requirement to finish import to create the venue.
8. **Creation / access:** submitting, slow/unknown result, validation errors, retry, confirmed creation, and access-refresh failure. Repeated clicks/retry stay on the same draft/operation, never suggest creating another venue. While result is unknown show “Verificar resultado” before a new creation attempt. When venue exists but access refresh fails show “Estabelecimento criado. Não foi possível atualizar seu acesso” and retry access refresh only. Workspace entry occurs only after confirmed creation and refreshed authorized venue access.
9. **AI menu branch:** for a confirmed venue, show a small handoff panel with mocked photo/file or URL input, processing, retry/error, and extracted-items preview requiring review before publication. Back returns to the created venue. Clearly label extraction as simulated; actual import behavior belongs to the existing menu-import journey. Do not claim a menu was published.

**INTERACTIONS**

- Editing updates a single wizard state, including values on unmounted steps. Debounced autosave and explicit “Salvar e sair” are separate from finalization. A saved acknowledgement must correspond to the current edit revision; an older response cannot mark newer edits as saved.
- Persist synthetic non-sensitive demo fields and checkpoints in versioned browser localStorage under an explicitly simulated owner ID so refresh/close/reopen demonstrates resume. Keep theme preference separate. Never store bank/Pix raw values, credentials, tokens, real owner information or file blobs in localStorage. Represent saved bank details after reload with a synthetic masked fixture only. Production persistence will be authenticated and server-backed.
- Resume to the first required invalid/unconfirmed step, then first optional unvisited step; an explicit “Agora não” resolves that optional step. When all steps are complete/skipped, resume Revisão. Choosing an earlier completed step allows editing without deleting later values. Saving mid-step preserves partial edits.
- Include save failure, offline/unsaved, stale-revision conflict, and session expiry during save. “Continuar editando” preserves local changes; retry uses the same draft. Conflict UI offers reload saved version or keep a local copy for review, never silent overwrite. Session expiry asks the user to sign in again and resumes only under the same authorized owner.
- Close with unsaved changes offers “Salvar e sair”, “Continuar editando”, or explicitly “Sair sem salvar alterações”. A failed save keeps the user in the flow; it never closes as if saved. Browser-close guidance must explain that only acknowledged progress is recoverable; do not promise asynchronous save on tab termination.
- On mobile touch/click outside an input, blur the active editable element and dismiss the keyboard. Do not intercept another control’s action, dismiss when interacting with its picker/listbox, or break text selection. Keep desktop Tab/Shift+Tab focus behavior intact. Also dismiss on explicit Back/Continue/Save actions. Scroll focused input/error into view with the keyboard open; use appropriate phone/email/numeric input modes and at least 16px input text to avoid mobile browser zoom.
- Provide visible focus, persistent field labels, associated hints/errors, logical tab order, aria-current for the step, live save/error announcements, dialog focus trapping and restoration, and at least 44×44px targets. Use text/icons as well as color for status. Support 200% text zoom and 320px–1440px viewports without horizontal page overflow. Focus the step heading on step navigation and first invalid field on validation failure.

**ANIMATIONS**

Use short 150–250ms transitions for step changes, save status and progress. Respect prefers-reduced-motion by removing movement and nonessential transitions. Never animate away errors or make the screen wait for decorative effects.

**TECHNICAL NOTE**

Deliver React + TypeScript source with separated theme tokens, Portuguese-first copy dictionary (English preview optional), reusable shell, step components, draft state model and mock repository interface. Include a dev-only scenario switcher to reach every error/loading/resume/conflict/creation state in both themes. Keep the switcher outside the production-like workflow. Use stable step keys and distinguish unvisited, in-progress, complete and skipped.

All responses, bank saving, creation, uploads, account identity and menu extraction are MOCKED. Place a clear “Protótipo · dados simulados” notice in the preview. No API keys, backend deployment, payment integration, production authorization or fabricated API success. Provide a README with run/export instructions, state fixtures, persistence limitations and the component/state map. Export the React repository so the human can supply its URL/local path and exact commit SHA for Flutter translation.

## Screen/state coverage

| Screens / states | Criteria | Review evidence requested |
|---|---|---|
| Find, identity, optional contact, receiving account, photos, hours, review and AI entry | B02-AC01 | Six-step navigation, skip paths and menu handoff in both themes |
| Start/resume, editing, saving/saved/offline/failure, close, stale conflict | B02-AC02 | Synthetic browser refresh/reopen, restored values and next incomplete step |
| Upload progress/failure/retry, invalid fields, submitting, unknown result, replay | B02-AC03 | Fixture walkthrough retaining one draft/creation operation |
| Signed out, wrong account/denied, masked bank resume, confirmed creation and access-refresh failure | B02-AC04 | UI states only; server authorization requires implementation tests |
| Theme control, contrast, responsive layout, keyboard dismissal, focus and reduced motion across all screens | B02 UX refinement; supports AC01–AC04 | Desktop/mobile screenshots and interaction review; no E2E claim |

## Legacy differences for product review

The [prompt collection](../../../fe/.docs/lovable_stitch_prompts.md) contains older dark-first and Flutter/React Native instructions, plus a broader Business Details editor. They are visual references: this brief requests React UI, both themes and B02 scope. Current [basic details](../../../fe/lib/features/bars/presentation/pages/create_bar/steps/basic_info_step.dart) require contact, and the [bank step](../../../fe/lib/features/bars/presentation/pages/create_bar/steps/bank_account_step.dart) requires bank details/business ID. B02-AC01 and the MVP source describe these onboarding sections as optional. The brief follows that intended optional behavior; the plan records the response-compatibility decision required before implementation. None of these mock states validate backend behavior.
