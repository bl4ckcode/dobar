# DNS Server Architecture
## Overview
DNS acts as the internet's phone book, translating domain names to IP addresses. The resolution path involves:
1. Browser/OS Cache check
2. Resolver Server (ISP)
3. Root Server (13 globally)
4. Top-Level Domain (TLD) Server
5. Authoritative Name Server (returns the IP)

DNS uses UDP for fast client queries and TCP for reliable server-to-server operations. Caching at the OS/Browser level significantly reduces latency and bandwidth usage.

## Correlation with Dobar Ecosystem
For our infrastructure (hosted on Fly.io, with web/Flutter clients):
- **Latency Reduction:** Efficient DNS resolution minimizes the initial connection latency (Time To First Byte) during user interactions (e.g., users scanning a QR code at a Barz venue).
- **TTL Configuration:** Ensure our custom domains have appropriate Time-To-Live (TTL) configured. A shorter TTL allows for faster failover across Fly.io regions, while a longer TTL reduces external DNS query overhead for frequent users.
- **Reliability:** By relying on robust managed DNS providers, we ensure our API endpoints remain highly available (as defined in our SCALABILITY_ASSESSMENT).
