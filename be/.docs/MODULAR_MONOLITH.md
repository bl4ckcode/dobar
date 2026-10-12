# Modular Monolith Architecture

## Design Principles
A modular monolith groups related functionalities within a single codebase, partitioned by business domains (e.g., `orders`, `payments`, `menus`). 
- **High Cohesion:** Code related to a specific domain lives together.
- **Low Coupling:** Modules communicate through well-defined public inter-module APIs (function calls). 
- Avoid cross-domain direct database queries or transcending transactions to achieve data isolation.

## Benefits vs Microservices
- Simpler deployment and operation (a single app, single repository).
- Lower network overhead (function calls instead of HTTP/gRPC overhead between microservices).
- Easier to reason about and refactor.
- Low infrastructure costs while still retaining an architecture that can be split into microservices later if scaling demands it.

## Correlation with Dobar Ecosystem
- **Barz-Backend:** Our backend should aggressively employ this pattern instead of fragmenting into tiny services prematurely. We have multiple domains (Dobar Payment Engine, Barz Menu Management, CRM/Advertising, Cart/Checkout).
- Keeping them as a modular monolith allows us to share core schemas (like `users`) while keeping modules cleanly separated.
- **Scalability (SCALABILITY_ASSESSMENT.md):** As we tackle more throughput, we scale the single fly.io app horizontally via Fly's autoscale, maintaining data isolation in the database schemas (e.g., `payments` schema vs `core` schema) so we can decouple later if required.
