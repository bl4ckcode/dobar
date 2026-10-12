# Dobar Repository Agent Guidelines

This documents serves as main guidance for the sub-repositories (fe, be, dpe and docs) for dobar ecosystem.

## fe
- **Front-end Flutter app**: under fe folder, there is our front-end application that uses Flutter and has its own AGENTS.md for architecture, tech stack, state management and development workflow.

## be
- **Back-end**: under be folder, there is our back-end application that uses FastAPI, Postgres, Redis, MongoDB and AWS; and also has its own AGENTS.md for architecture, tech stack, state management and development workflow.

## dpe
- **Dobar-payment-engine**: under dpe folder, there is multi-gateway payment engine that uses PagarMe (Brazil), Stripe (LATAM) and Paypal for international payments; it also has its own AGENTS.md that should be referenced when working on payment-related features.

## docs
- **Documents**: under docs folder, there are businesses files, front-end and back-end communication between agents, back-end and dobar-payment-engine communication between agents, market analysis and this folder should be considered source of truth.
