# Development Workflow

This document outlines the workflow and verification guidelines when developing for the Dobar client application.

## Core Workflow Steps
1. **Dependency Injection & Code Generation**:
   Whenever you modify classes that use code generation (e.g., `@freezed`, `@JsonSerializable`), you must regenerate files using:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
2. **Backward Compatibility**:
   - Ensure that all changes to API contracts, local storage schemas, and model structures maintain backward compatibility for existing users and production data.
3. **Verification**:
   - Run tests to verify the integrity of the application:
     ```bash
     flutter test
     ```
4. **Back-end support, services/endpoints request and fixes**
   - Update the canonical [FE ↔ BE contract](../../../docs/FE_BE_COMMUNICATION.md) when wire behavior changes; put requested behavior and acceptance criteria in the relevant root spec.
   - We clean up the file with outdated/irrelevant information so it always stays relevant, up-to-date, concise and easy to understand.
5. **Our UI/UX design is always loyal to @dobar_colors and Lovable generated projects**
   - We very often ask Lovable to generate our UI's and Workflows designs, we store the prompts in @lovable_stitch_prompts.md and follow the patterns there.
   - Lovable generates React UI source. Record its exported repository revision and translate it to Flutter using the existing architecture, localization, semantic theme tokens, responsive light/dark UI, and the `dobar-react-to-flutter` skill. Do not assume the export is React Native.
