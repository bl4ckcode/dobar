# Dobar frontend agent guidelines

Production Flutter app for customer mobile journeys and business browser journeys. Read [root instructions](../AGENTS.md) first.

- Preserve existing user data and API compatibility. Follow feature/domain/data/presentation boundaries, BLoC/Cubit, repositories, and existing dependency injection.
- Read [architecture and state management](docs/agents/architecture.md) and [development workflow](docs/agents/development_workflow.md).
- Use semantic theme tokens from the existing design system, localized Portuguese copy, and responsive light/dark designs. Translate actual exported Lovable React source using the recorded revision.
- Current wire contracts live in [docs/FE_BE_COMMUNICATION.md](../docs/FE_BE_COMMUNICATION.md); the [error contract](.docs/API_ERROR_CONTRACT.md) remains canonical for errors. Record disagreements as findings rather than copying stale examples.
- Run `flutter analyze` and affected `flutter test` suites. Run `dart run build_runner build --delete-conflicting-outputs` only when generated model/DI inputs change; generate localization when localization inputs change.
- Preserve root Git/deployment safeguards. UI implementation alone does not validate native wallets, provider payments, or E2E workflows.
