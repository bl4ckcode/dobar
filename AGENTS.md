# Dobar Repository Agent Guidelines

This is dobar monorepo structure, which contains four main directories:
- **fe**: Front-end Flutter app
- **be**: Back-end application
- **dpe**: Dobar-payment-engine
- **docs**: Documents

Each directory has its own AGENTS.md file that should be referenced when working on that specific directory.

## fe
- **Front-end Flutter app**: under fe folder, there is our front-end application that uses Flutter and has its own AGENTS.md for architecture, tech stack, state management and development workflow.

## be
- **Back-end**: under be folder, there is our back-end application that uses FastAPI, Postgres, Redis, MongoDB and AWS; and also has its own AGENTS.md for architecture, tech stack, state management and development workflow.

## dpe
- **Dobar-payment-engine**: under dpe folder, there is multi-gateway payment engine that uses PagarMe (Brazil), Stripe (LATAM) and Paypal for international payments; it also has its own AGENTS.md that should be referenced when working on payment-related features.

## docs
- **Documents**: under docs folder, there are businesses files, front-end and back-end communication between agents, back-end and dobar-payment-engine communication between agents, market analysis and this folder should be considered source of truth.

- **FE_BE_COMMUNICATION**: under docs folder, there is a file that describes the communication between front-end and back-end applications. Keep it updated and as short as possible, it's not necessary to document the whole FE and BE architecture, just the key endpoints and data structures.

- **BE_DPE_COMMUNICATION**: under docs folder, there is a file that describes the communication between back-end and dobar-payment-engine applications. Keep it updated and as short as possible, it's not necessary to document the whole BE and DPE architecture, just the key endpoints and data structures.
