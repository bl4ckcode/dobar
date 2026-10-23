---
owner: product
spec: B08
artifact: lovable-prompt
status: ready
---

# Lovable prompt: accept a Dobar staff invitation

Source: [existing Lovable style](../../../fe/.docs/lovable_stitch_prompts.md), [B08 acceptance spec](../B08-staff-invitation-acceptance.md). Paste the quoted brief below into Lovable. This is a React design/source handoff; Flutter translation follows a reviewed export.

> Build a premium, responsive **React + TypeScript** staff-invitation acceptance experience for **Dobar**, a Brazilian bar and restaurant platform. Produce runnable React components and UI state fixtures. The result will later be translated into Flutter. Use Lucide icons. Do not generate Flutter code.
>
> **CONTEXT**
>
> A bar owner invites an employee using their existing Google/Apple account email or phone number. The employee opens the invitation link or enters its code. They authenticate using Dobar's existing phone/SMS, Google or Apple login, return to this invitation, review it and explicitly accept. Opening a link and logging in never grant membership. This is a business browser journey with comfortable mobile-browser support. Use Portuguese from Brazil for every user-facing string.
>
> **OVERALL VIBE**
>
> Keep our Industrial Modern visual language: premium, professional, reassuring and readable under busy bar conditions. Dark theme uses deep black #0A0A0A, matte surfaces #121212 / #1A1A1A and electric gold #FFDE59. Light theme uses #FFFFFF background, warm neutral surfaces, deep readable labels and the same gold accent with dark CTA text. Use Space Grotesk headings and clean system body typography. Error color #FF4B4B and success green #00B37E are semantic status accents; text/icon/shape also communicates state. Provide dynamic light/dark themes via semantic CSS variables. Avoid hardcoded dark-only foregrounds.
>
> **PAGE STRUCTURE**
>
> 1. Branded header with Dobar mark/name, discreet theme toggle and a back action. Wide browser: centered card with restrained decorative background, maximum form width about 480px. Narrow browser: full-width comfortable card with 24px side padding and no horizontal scroll.
> 2. After matching, verified login, invitation preview shows venue image or tasteful fallback, “Você recebeu um convite”, venue name, address if supplied, offered role badge and masked recipient (for example `ca***@exemplo.com` or `(**) *****-1234`). Display “Válido até …” from fixture data. Show a concise permission summary using human labels rather than internal permission codes.
> 3. Identity section: signed-out view says “Entre para continuar” and offers “Continuar com Google”, “Continuar com Apple” and “Continuar com telefone”. The real app will reuse its existing login pages; the prototype callback returns to this invitation. Signed-in view says “Você está conectado como …” and offers “Trocar conta”.
> 4. Primary action after matching, verified login: “Aceitar convite”. Supporting copy: “Ao aceitar, você terá acesso ao espaço de trabalho deste estabelecimento.” Secondary: “Agora não”. Disable repeat submission while processing.
> 5. Success: clear check icon, “Convite aceito!”, venue and role confirmation, and “Entrar no estabelecimento”. Entering the workspace uses the confirmed server access, not a local role assumption.
> 6. Manual-code entry reachable from the business onboarding action “Aceitar convite”: input label “Código do convite”, help “Cole o código recebido por e-mail ou mensagem” and “Continuar”. Pasting a complete supported link may extract the code; empty/malformed input stays inline and never pretends acceptance.
>
> **REQUIRED STATES AND COPY**
>
> - Loading preview: skeleton card plus “Carregando convite…”; screen reader status announcement.
> - Signed out: full login choices with only generic invitation frame; code context retained after cancel/return, and recipient-bound details load after matching verified authentication.
> - Matching verified account: enabled explicit acceptance, identity and role visible.
> - Wrong account: “Este convite foi enviado para outra conta.” with “Trocar conta”; do not enable acceptance or expose private staff details.
> - Unverified target contact: “Confirme seu e-mail ou telefone para continuar.” with the appropriate existing verification action.
> - Accepting: “Aceitando convite…” with progress; prevent duplicate actions and retain context.
> - Success / same-recipient already accepted: “Você já faz parte da equipe.” and workspace-entry action using confirmed access.
> - Expired: “Este convite expirou.” and “Peça um novo convite ao responsável pelo estabelecimento.” No accept button.
> - Revoked: “Este convite foi cancelado.” with the same request-new-invite guidance.
> - Invalid or used by another recipient: “Não foi possível usar este convite.” and safe guidance to contact the inviter; reveal no other person's identity.
> - Network/server failure: “Não foi possível carregar o convite. Tente novamente.” or “Não foi possível confirmar sua entrada. Tente novamente.” Retry keeps the invitation and identity context.
> - Decline/dismiss: “Agora não” returns to business onboarding without consuming the invitation or changing membership.
>
> **INTERACTION AND ACCESSIBILITY**
>
> All controls work with keyboard, visible focus, labels and screen-reader semantics. Status changes use appropriate live regions; destructive/error states never rely on color alone. Respect reduced motion. Use subtle fade/slide card entry and a brief success animation without blocking navigation. Keep primary actions at least 44px high and support text enlargement. Never trap focus in the login-return or error path. Show light and dark versions and mobile/desktop responsive behavior.
>
> **OUTPUT AND STATE BOUNDARY**
>
> Provide reusable `InvitationPage`, `InvitationCard`, `IdentityPanel`, `InvitationStatus` and `ManualCodeForm` React components (equivalent clear naming is fine), semantic tokens, and typed state fixtures for all states. Connect actions through callbacks (`onLogin`, `onSwitchAccount`, `onVerifyContact`, `onAccept`, `onRetry`, `onEnterWorkspace`, `onDismiss`) so real authentication/networking can be integrated later. Fixtures may simulate UI transitions for review; label fixtures in source and never represent them as live authentication or membership creation. Keep UI copy in an organized Portuguese dictionary ready for Flutter localization. Do not include secrets, real invitation tokens, payment collection, admin permission editors or a replacement login system. Export the full runnable React repository for review and subsequent Flutter translation.

## Review gate

Product reviews the actual React states against B08-AC01, AC02, AC05 and AC06. Record export repository and immutable revision in [source handoff](react-source-handoff.md). Screenshots alone are insufficient source for translation. A mock React prototype does not establish backend acceptance or security.
