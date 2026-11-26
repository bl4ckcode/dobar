---
owner: product
---

# Order lifecycle specifications

These are order and refund capabilities decided after the fixed 25-journey MVP inventory. They extend MVP journeys (C11, B04, B05, S02) without changing those journeys' IDs. Revise each spec in place, preserve acceptance IDs, and use Git/Linear for history.

| Spec | Capability | Status |
| --- | --- | --- |
| [R01](R01-order-cancellation-refunds.md) | Customer cancellation before acceptance, refund requests to the venue, refund window, safe refund ledger | Ready / unverified |

```sh
python -m tools.agent_workflow --catalog order-lifecycle validate
python -m tools.agent_workflow --catalog order-lifecycle handoff --spec R01 --role cross-repo-planner
```
