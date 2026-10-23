# Dobar MVP

## Mission

To become the biggest payments platform for bars and restaurants until 2030

## Vision

Dobar ecoystem has a main goal digitalizing, providing agility and AI to bars and restaurants public service processes

## Pillars

- **Automation**: use of technology and AI to speed up customer service
- **Security**: allow users to pay with their device with security
- **Efficiency**: monitoring and validation from business side
- **Acessibility**: all done by user's own device

### MVP Features

*Client workflow*: Login with cellphone number, Google or Apple account

1. App first look appearance

    Non-authenticated area | 1.  Minimal onboarding: number login or Google/Apple account -> confirm SMS -> send to Home and enable Location permission to dobar
                                 1.1 "Are you a business button?" -> send to Business workflow
    Bottom nav. bar        | 2.  Home: near bars and restaurants sections, most ordere drinks, trending in your area, promotions
                           | 3.  Map: pins of partner bar/restaurant; pins of. promotions; ability to draw route to bar/resutarant; ability to send to Maps apps
                           | 4.  Profile: account options, preferences, delete my data compliance of App/Google stores
                           | 5.  Check-in button: appear only if <10m of a partner bar/restaurant

2. Check-in

    - User check-in can be made when location is <10m of bar/restaurant location
    - User may indicate where he is located at the bar
    - User can check-in before or when he is just about to make an order

3. Details screen

    - Bar/restaurant menu with categories and sub-categories if applicable
    - Items with increment and decrement buttons, prices with or without promotions
    - Real time live data update
      1. changes in the price by business must reflect users currently browsing
      2. changes in the amount of items available by business must reflect users currently browsing
      3. changes in a group of items must reflect users currently browsing
    - Proceed to checkout must double check cart validation

4. Cart screen

    - Edit order
    - Insert reedem code
    - Confirm location given by check-in or indicate where user is so that the order should be delivered at

5. Checkout screen

    - Pay with: PIX or Credit Card (via Apple or Google Pay as well).

6. Order tracking page

    - Must transit states: Pending -> Preparing -> Ready -> Completed
    - Sockets or event driven UI

*Business workflow*:

1. Web first look appearance

        Non-authenticated area |                          | 1.  Login: number login or Google/Apple account -> confirm SMS
                                                            1.1 Optional onboarding: imagens of bar/restaurant, AI Menu Reader, contact information, bank account information (allow to save progress)
        Side menu.             | Account Owner/Admin View | 2.  Home: Profit/Revenue/Total num. orders/Economy(vs credit card machine or physical token machines) 
                               | Cashier View and Above   | 2.1 Orders Table summary that if clicked send directly to Cashier/Orders live sockets page
                               | Users with ads:view permission | 2.2 Campaigns Table summary that if clicked send directly to Campaigns
                               | Cashier                  | 3.  Orders page must be sockets or event driven oriented whose updates reflects to the clients instantly
                               | Users with ads:manage permission         | 4.  Campaigns page have marketing campaigns with several customizations available
                               | Users with staff:manage permission       | 5.  Staff page allows invitation by e-mail (admin have special privilleges and can give too)
                               | Users with bar:edit permission     | 6.  Settings page contains a lot: basic information, bank account info, account preferences overall

2. Orders screen

   - Pipeline of order states: Pending -> Preparing -> Ready -> Completed
   - Must be sockets or event driven oriented whose updates reflects to the clients instantly
   - Permissions: order:view to view, order:process to advance orders; existing roles remain

3. Campaigns screen
   - Multi-step campaigns creation, immersive 5-step experience inspired by Meta Ads. Available placements: Feature Bar, Search Boost, Map Pin Highlight, Promo Boost, Banner Ads
   - The five steps are as follows allowed to set Budget, Creative (images, banners), Target Public, Review
   - VIP banner for Regular tiers users are visible so one can acquire a subscription and create campaigns
   - Permissions: ads:view to view, ads:manage to create/manage; existing roles remain
4. Staff screen
   - Invite Staff members by Google/Apple account e-mail or phone-number
   - Back-end sends an invitation by e-mail or phone. Staff authenticate through existing login methods, resume the invitation, verify the matching contact, and explicitly accept before receiving access
   - Permissions: staff:view to view, staff:manage to invite/manage; existing roles remain
5. Settings screen
   - Account data and working hours require bar:edit; bank/account financial changes require billing:manage; password, account deletion, and language preferences apply to the authenticated account
