# HTTPS and TLS Security

## How HTTPS Works
HTTPS secures HTTP traffic via Transport Layer Security (TLS). It guarantees authenticity, confidentiality, and integrity.
- **TLS Handshake:** 
  1. Client sends a random string and supported algorithms.
  2. Server responds with its certificate and server random string.
  3. Client verifies the certificate via a Certificate Authority.
  4. Client encrypts a pre-master secret with the server's public key.
  5. The server decrypts it with its private key.
  6. Both generate a symmetric **session key** for encrypting ongoing traffic.

## Correlation with Dobar Ecosystem
- **Dobar Payment Engine (BE_DPE_COMMUNICATION.md):** Encrypted HTTPS is non-negotiable for transferring sensitive payment attributes, cards, or user personally identifiable information (PII). 
- **Internal Fly.io Network:** While HTTP might be used inside secure VPCs/WireGuard meshes (like Fly's internal `.internal` network between web nodes and Redis/Postgres), all external traffic (Mobile -> Fly.io) must enforce strict HTTPS.
- **Certificates:** We rely on managed certificates for our endpoints. We must ensure robust certificate validity and automated renewal pipelines to avoid disastrous user-facing downtime.
