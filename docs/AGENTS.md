# Dobar documentation agent guidelines

Read [root instructions](../AGENTS.md) and [context authority/findings](AGENT_CONTEXT.md).

- `docs` owns durable product decisions and current integration summaries. `.specs/mvp-v0.1` owns desired journey behavior, acceptance criteria, and evidence status.
- Update [FE ↔ BE](FE_BE_COMMUNICATION.md) and [BE ↔ DPE](BE_DPE_COMMUNICATION.md) in place; keep them concise and source-linked. Old area paths are compatibility links, not duplicate documents.
- Check actual source before calling a wire shape current. Record intended/observed contradictions with evidence and an owner; never silently replace one with the other or convert historical completion claims into current validation.
- Preserve valuable historical requirements/examples in clearly marked noncanonical archives. The [API error design](../fe/.docs/API_ERROR_CONTRACT.md) remains canonical for FE errors.
- Keep the MVP source and requirement-coverage manifest aligned when changing approved intent. Do not mark a spec verified without acceptance evidence.
- Use [workflow commands](AGENT_WORKFLOW.md) for deterministic validation and ticket/handoff generation. Preserve user work and root Git/deployment safeguards.
