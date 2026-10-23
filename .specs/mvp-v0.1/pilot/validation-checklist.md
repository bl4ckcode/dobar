---
owner: verifier
spec: B08
artifact: validation-checklist
status: unverified
---

# Independent staff-invitation validation

Use [B08](../B08-staff-invitation-acceptance.md) criteria and [implementation contracts](implementation-tasks.md). No checks below have run in this delivery. Initial result: **unverified**, with Lovable export/provider delivery/device environments pending. Record passed, failed, blocked and skipped separately.

| Scenario | Required observation | Criteria |
|---|---|---|
| Invite existing email/phone account | Delivered invitation remains pending; account has no new membership before accept | B07-AC02, B07-AC03; B08-AC01 |
| Invite new recipient | Link survives existing registration/phone or Google/Apple login and returns to preview | B08-AC01 |
| Signed-out preview | Generic login frame only; code alone cannot log in or disclose private roster/contact | B08-AC01, B08-AC02 |
| Verified matching email | Explicit acceptance returns BarAccess and correct venue access | B08-AC02, B08-AC03, B08-AC04 |
| Verified matching phone | Same behavior with normalized phone; unrelated matching display text cannot bypass verification | B08-AC02, B08-AC03 |
| Wrong/unverified account | Guidance to switch/verify, no membership, no code consumption | B08-AC02 |
| Cancel provider login / close browser | Resume safely without membership or losing intended invitation | B08-AC01 |
| JSON body / legacy query / conflict | Both compatible valid forms succeed; conflict fails; BarAccess fields decode in Flutter | B08-AC04 |
| Concurrent/repeated accept | One membership and one accepted user; same recipient obtains consistent access | B08-AC03 |
| Another recipient reuses accepted code | Safe rejection; no second membership | B08-AC03, B08-AC05 |
| Transaction fails halfway | Neither partial membership nor consumed invitation; safe retry | B08-AC03, B08-AC05 |
| Expired/revoked/invalid code | Distinct safe state and new-invite guidance; no access | B08-AC05 |
| Previously removed member replays code | No silent membership restoration | B08-AC03, B08-AC05 |
| Network timeout after acceptance | Retry/readback resolves actual result, one workspace entry | B08-AC03, B08-AC04, B08-AC05 |
| Venue context/permissions | `/me/bars` refresh, correct selected venue, direct restricted actions denied | B08-AC04 |
| Narrow/wide + dark/light | All states readable, theme token alignment, no clipped actions | B08-AC06 |
| Keyboard/screen reader/text scale | Focus order, live announcements, labeled controls and motion preference work | B08-AC06 |
| Provenance and handoffs | Real exported React revision, approved prompt states and scoped FE/BE tickets recorded | B08-AC06 |

For each executed row capture checkout commit, environment, account roles/contact-verification fixture (redacted), browser/OS, action, expected/actual result and artifact path. Record targeted FE/BE contract/test command outcomes. Keep real invite codes, contact values and auth secrets out of screenshots/logs.

Foundation validation only confirms spec/skill/reference structure. Hand-created invitations verify acceptance components but do not prove B07 delivery. A simulated login or React fixture cannot validate identity binding. Backend test passes do not replace browser resume and accessible UI checks. Only the independent verifier may recommend validated after every applicable B08 criterion has evidence; retain blocked status for missing source export, delivery service, verification capability or environment access.
