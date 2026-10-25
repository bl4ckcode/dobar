---
name: dobar-communication-docs
description: Update Dobar FE/BE or BE/DPE communication notes as bounded rolling handoffs, retaining only the latest update from each sending area and using Linear and Git for history.
metadata:
  owner: product
---

# Rolling communication handoffs

## Inputs and context

Read the affected source, actual diff, linked Linear issue/spec, and [documentation instructions](../../../docs/AGENTS.md). Choose [FE/BE](../../../docs/FE_BE_COMMUNICATION.md) or [BE/DPE](../../../docs/BE_DPE_COMMUNICATION.md) according to the boundary. Update both only when both boundaries changed.

## Update and replace

- Keep the title, `Last updated: YYYY-MM-DD`, a short `Contract references` section, and exactly two sender sections: `Latest frontend update` / `Latest backend update`, or `Latest backend update` / `Latest DPE update`.
- Identify the area that produced the change, not the model writing the note. Replace that area's entire previous update and preserve the other area's latest update. A BE change affecting both boundaries replaces the BE entry in both docs.
- Each sender entry contains date, Linear/spec reference, changed endpoint/fields/units or behavior, recipient action/compatibility, and source/test evidence. Distinguish requested, implemented, inspected, tested and deployed; do not invent a recent code change or a successful check.
- Update the document date to the actual edit date in the user's timezone. Keep an unchanged sender's original date. If no change is known for a sender, say so rather than fabricating one.
- Delete replaced entries, superseded examples, changelogs, append-only sprint notes and repeated architecture. Keep each document at most 80 lines; link schemas/routes for full wire definitions. Do not add a Markdown archive for routine history: Git and the linked Linear issue own it.
- Preserve unresolved requirements and compatibility obligations in their owning spec or Linear issue before removing their last actionable reference. Link existing context findings rather than repeating them. Keep old compatibility paths pointing to the canonical root docs.

## Output and validation

Deliver the concise updated note with one entry per sender and a short summary of what was replaced. Run `python -m tools.agent_workflow validate` to check date, section counts, size, and links. This validates document structure, not API correctness. Do not create external comments/issues or change Git history unless the current task authorizes that operation.
