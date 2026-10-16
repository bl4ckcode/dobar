### Oct Q4 Bugs

1. **NOT FIXED** [x] Fix the subscription lifecycle **most likely back-end issue**

Response from DPE is 200:

{
  "id": "000000000000000003e1d27ddd85c3c4d6a49efb5836f310-1791845408743932230",
  "message": "INFO:     172.16.16.42:41812 - \"POST /payments/charge HTTP/1.1\" 200 OK",
  "timestamp": "2026-10-12T22:50:08.743Z",
  "level": "info",
  "instance": "e827941c774478",
  "provider": "app",
  "region": "gru",
  "process_group": null
}

Refer to be/flyio-campaignssubscribe-error.log for back-end log and fe/console-campaigns-error.log for front-end log

1. [x] Fix business dashboage page and campaigns page reactivity **front-end issue**

When resizing the window, the pages are throwing errors and not rendering correctly, refer to fe/logging-business-dashboard.json and fe/logging-campaigns.json for more details

4. [ ] Cashier page needs to be updated **back-end issue** — pending (Linear DOB-85)

Cashier page is showing pending orders from hundreds of minutes ago, orders never expire. This happens for all the tabs.
This must be fixed by setting a timeout for the orders to expire to the business operating hours of the day the order was created/updated.
This must be fixed on be because it is the one that returns the orders for fe to show.

5. [x] Phone code screen to be polished **front-end issue**

fe/lib/features/authentication/presentation/pages/login_sms_validation_page.dart does not support dark/light theme preference of the app, it always shows light background with black toolbar and black disabled button (yellow enabled is correct) but it must also follow the app preference. 

6. [ ] Campaigns light theme is not working properly **front-end issue** — pending (Linear DOB-86)

Campaigns page is not showing the light theme correctly, it is showing the dark theme for the cards and buttons.
Most specifically: Impressions card at the right, Most recent filter, campagins types badges, campaigns created cards, overall performance.
Campaigns also does not offer light/dark theme toggling

7. [x] Staff invitation is not working **back-end issue**

Both back-end and front-end are not working properly, refer to be/flyio-staff-invite-error.log and fe/console-staff-invite-error.log for more details

8. [ ] Staff page does not offer light/dark theme toggling **front-end issue** — pending (Linear DOB-87)

Staff page does not offer light/dark theme toggling like business_dashboard_page.dart does, it must include a light/dark theme toggle button on the left side of the Invite Staff button.

9. [x] Staff page does not show the name of the staff member **front-end issue**

[DIO] [{id: 1, user_id: 6, bar_id: 16, role: owner, nickname: null, employee_id: null, is_active: true, display_name: Carlos Augusto Alves, email: carlosaugusto1337@gmail.com, phone: +5531988918273}]

Even though the display_name is being returned, it is not being shown on the staff page.

10. [ ] Prepare Lovable Prompt to polish UI/UX **front-end issue** — pending (Linear DOB-88)

Prepare Lovable prompts, following fe/.docs/lovable_stitch_prompts.md pattern of keeping system design, colors, fonts, and overall aesthetic consistent with the app.

The following pages must be refined/polished, always stating that we need to support dark/light theme app preference, light theme should have dark text colors, dark theme should have light text colors. Create prompts for the following pages:

- Login Screen
- Phone Code Screen

