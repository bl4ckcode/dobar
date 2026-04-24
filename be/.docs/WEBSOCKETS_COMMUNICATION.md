# WebSockets Real-Time Communication

## Overview
WebSockets provide a persistent, full-duplex TCP connection between the client and server.
- **Handshake:** Connection starts via an HTTP GET request asking for a protocol upgrade. Server responds with `101 Switching Protocols`.
- **Data Transfer:** Messages can be split into frames for performance. Allows bidirectional real-time text and binary data transfer.
- **Closing:** A specific websocket frame code is used to gracefully close the connection.
- **Trade-offs:** Server must maintain state (memory/socket limitations). Not always a silver bullet compared to polling or Server-Sent Events (SSE).

## Correlation with Dobar Ecosystem
- **Barz Venue POS:** For live updates of new incoming orders or checkout completions, WebSockets provide low-latency notifications across the venue network, replacing aggressive polling.
- **Client App Updates:** While full WebSockets might be heavy for all individual customer mobile apps, SSE or targeted WebSockets can notify users when their order is ready for pickup or when their payment is approved via the `Dobar Payment Engine`.
