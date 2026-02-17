# Frontend Sprint 1: Security & Auth Foundation

**Context:**
The Backend (BE) has completed Sprint 1 implementation for advanced security features. Now it's time for the Frontend (FE) to implement the UI/UX for these features in the `barz` Flutter app.

**Your Goal:**
Implement the following features in `barz` (Flutter), ensuring seamless integration with the new backend endpoints. Use the `linear-mcp-server` to update task status in real-time.

---

## 1. Linear Integration
- **Connect:** verification of Linear tickets (DOB-5 to DOB-9).
- **Update:** As you implement each feature, move the corresponding Linear ticket to "In Progress" and then "Done".
- **Comment:** Add links to PRs or screenshots in the Linear tickets.

## 2. Key Features to Implement

### A. Multi-Factor Authentication (MFA) [DOB-5]
- **Settings Screen:** Add "Two-Factor Authentication" toggle in User Profile.
- **Setup Flow:**
  - Call `POST /auth/mfa/setup` -> Display Secret Key (copyable) & QR Code.
  - User enters TOTP code -> Call `POST /auth/mfa/verify`.
  - Store `recovery_codes` securely (display them to user).
- **Login Flow Update:**
  - Handle `200 OK` response with `mfa_required: true`.
  - Redirect user to "Enter 2FA Code" screen.
  - Call `POST /auth/mfa/challenge` with the `mfa_token` and user input.
  - On success, store the final `access_token` and proceed.

### B. Account Recovery [DOB-6]
- **Login Screen:** Add "Trouble logging in?" or "Recover Account" link.
- **Initiate:** Input email -> `POST /auth/recovery/initiate`.
- **Verify:** Logic to handle deep link or manual token entry -> `POST /auth/recovery/verify`.

### C. Data Exclusion (GDPR/LGPD) [DOB-7]
- **Profile Settings:** Add "Delete Account" button (Red, danger zone).
- **Confirmation:** Show strict warning dialog ("This action is irreversible").
- **Action:** Call `DELETE /me/data`.
- **Feedback:** Show success message and logout user immediately.

## 3. Resources
- **API Documentation:** Refer to `.docs/FE_BE_COMMUNICATION.md` (section `SECURITY & AUTH (SPRINT 1 - NEW)`) for exact payloads.
- **Roadmap:** See `.docs/DBE_ROAD.md` for context.

---

**Action Plan:**
1. Read the docs mentioned above.
2. Check Linear tickets.
3. Start with the "Delete Account" feature (simplest).
4. Move to MFA Setup & Login flow (most complex).
5. Finish with Account Recovery.

Let's build a secure and premium experience! 🚀
