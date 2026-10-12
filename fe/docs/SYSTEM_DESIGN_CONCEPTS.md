# Core System Design Concepts

## Scalability & Performance
- **Horizontal vs Vertical Scaling:** Adding more machines vs increasing the power of existing machines.
- **Throughput vs Bandwidth:** Actual data transferred in a period vs potential data capability.
- **Concurrency vs Parallelism:** Rapidly switching tasks vs simultaneously executing them.

## CAP & PACELC Theorems
- **CAP Theorem:** Guarantee at most two out of Consistency, Availability, and Partition Tolerance.
- **PACELC Theorem:** Without network partitions, the trade-off is between Latency and Consistency.

## Latency Reduction
- Data Replication, Caching, Sharding, and Load Balancing (e.g., Round Robin, Least Connections).

## Databases and APIs
- **Databases:** Relational (ACID compliance: Atomicity, Consistency, Isolation, Durability) vs Non-Relational (BASE transactions: Basically Available, Soft state, Eventual consistency).
- **APIs:** REST (Stateless, standard HTTP verbs), SOAP (XML, structured), GraphQL (Client demands specific data).

## Correlation with Dobar Ecosystem
- **FE_BE_COMMUNICATION.md:** Our Flutter frontend communicates strictly via REST APIs with our Fly.io backend.
- Understanding PACELC helps in designing our offline-first features for the Barz POS when venue internet goes down, favoring Availability over strict Consistency temporarily.
- **Database Architecture:** We use PostgreSQL (ACID) for rigorous Barz business transactions (menus, payments via DPE), but might use Redis for BASE-style fast transient state (cart/promotions caching).
