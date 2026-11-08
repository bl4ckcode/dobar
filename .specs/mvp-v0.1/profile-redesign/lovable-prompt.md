---
owner: product
spec: C04
artifact: lovable-prompt
---

# Customer profile React design prompt

This records the approved prompt intent from the planning conversation. The exported implementation is separately pinned in the [source handoff](react-source-handoff.md); this document does not claim that every generated screen satisfies the prompt. See the [acceptance matrix](validation-checklist.md).

## CONTEXT

Build an exportable React + TypeScript prototype for the Dobar customer profile and its destination screens. Dobar serves bars and restaurants in Belo Horizonte, Brazil. Default to Brazilian Portuguese and BRL formatting. Preserve the recognizable customer shell: home, discovery, central check-in, cart and profile. Pagamentos belongs inside Perfil, not in a new global navigation tab.

The supplied screenshot is unfinished context. Redesign profile content and destinations with deterministic synthetic fixtures and clearly simulated outcomes. Do not connect production services or claim real persistence/payment/deletion.

## OVERALL VIBE

Use Industrial Modern styling: restrained gold accents, readable typography, Lucide icons, clear hierarchy, compact grouped cards and subtle borders. Guide palette: gold #FFDE59, black #0A0A0A, dark surfaces #121212/#1A1A1A; provide warm light surfaces and readable derived foregrounds. Use semantic CSS tokens, success green for cashback and semantic error colors for destructive actions. Avoid oversized empty headers, heavy shadows and decorative gradients.

## PAGE STRUCTURE

### Perfil — C04-AC05, AC09

Compact title; no flask, developer toolbar, showcase sheet or demo shortcuts. Prominent clickable Conta card: “Seus dados e privacidade.” No avatar, placeholder portrait, upload or camera action.

- Atividade: Histórico de pedidos; Cupons, cashback e recompensas.
- Preferências: Pagamentos; Configurações.
- Secondary group: Termos de uso; Política de privacidade; destructive Sair.

Derive benefit badges from fixtures and hide zero. Do not introduce a support/chat product.

### Conta — C04-AC01–AC04

Name, email and phone view/edit with labeled fields, Brazilian phone formatting and missing values. Include validation, saving, simulated saved outcome, retryable failure and unsaved-change cancellation. Changing profile contact details does not verify them or change login credentials.

Keep privacy controls and Excluir conta reachable. Include explicit deletion confirmation, processing, failure and simulated completion without claiming real deletion or compliance.

### Histórico de pedidos — C04-AC06, C11

Newest first: venue, date, order identifier, localized status, items and BRL total. Open matching details and timeline. Standard stages: Pendente, Em preparo, Pronto, Concluído. Preserve accurate cancelled/legacy records without adding normal workflow stages. Include populated, empty, loading, load-more, retryable error and unavailable-order states.

### Cupons, cashback e recompensas — C04-AC07, C02

Distinguish active coupons, available cashback and rewards. Show benefit, conditions, validity and eligible venue scope using synthetic examples without defining new earning/redemption rules. Clicking any benefit opens Onde usar with only eligible bars/restaurants; preserve selected benefit identity, terms and title. Selecting a venue opens a contextual preview with that benefit visible. Navigation never redeems, applies or guarantees a discount.

Include one/multiple venues, zero balance, no active benefits, expired/unavailable benefit, no eligible venues, loading and retryable failures. Do not combine different currencies, reward units or eligibility scopes into a fabricated balance.

### Configurações — C04-AC01, AC02

Notification preferences: Notificações push, Atualizações de pedidos, Promoções e novidades. Distinguish app preferences from device permission; demonstrate OS permission disabled. Language: Português (Brasil), English, Español; Portuguese initial preview. Include changes, saving and failure recovery without claiming backend persistence. Privacy controls stay reachable from Conta without conflicting duplicates.

### Pagamentos — C04-AC08, C08, C10

Masked saved credit cards: brand, last four, expiry, existing default status. Actions: Adicionar cartão, Substituir cartão, Remover. Replacement adds a new card securely before removing the original. Add failure keeps the original. If replacement saves but removal fails, show both and safe removal retry. Confirm removal with masked identity.

Include incomplete-account prerequisites, empty/loading/submitting/validation/service unavailable/retry/simulated success. Card entry is a nonfunctional provider placeholder: never collect/transmit/log/persist real card data or generate fake tokens.

Apple Pay appears only in supported/configured iOS preview; Google Pay only in supported/configured Android preview. Include unsupported states; wallets are device capabilities, not editable saved cards. No saved Pix entries or charges from this screen.

## INTERACTIONS

All in-scope navigation/back actions work locally. Returning preserves selected order/benefit context. Cancelling keeps prior data; failure preserves nonsensitive draft values and offers retry. Preserve legal/logout entry points, using clearly labeled legal placeholders rather than invented legal text; logout confirms and simulates signed-out state.

Support narrow mobile/tablet/desktop without stretching cards across desktop. Use keyboard navigation, visible focus, semantic controls/headings, screen-reader labels, announced errors, modal focus containment/restoration, ≥44px targets, readable contrast and text scaling. Keep content clear of bottom navigation, safe areas and keyboard.

## ANIMATIONS

Use short restrained transitions. Respect reduced motion; no loops or mandatory entrance animations.

## TECHNICAL NOTE

Export runnable React + TypeScript with separate components, semantic tokens, localized dictionaries (Portuguese, English, Spanish), deterministic fixtures and mock state outside presentation. Put platform/theme/scenario review controls on a separate prototype route, not Perfil. README must list run/build commands, screens, fixture states, asset provenance and criterion mapping. Visual mock coverage cannot establish backend, provider or native-device acceptance.

Human handoff: generate in Lovable, export actual source, record repository/local path + exact immutable revision + entrypoints/assets + reviewed screenshots, then use dobar-react-to-flutter. This export is now supplied; production gaps remain recorded separately.
