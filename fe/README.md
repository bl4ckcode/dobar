# BarZ App

Welcome to the **BarZ App** repository! This Flutter project is the user-facing mobile application for BarZ – an app that lets users browse bars and restaurants, view dynamic menus, order drinks/food, and have them delivered directly to their table or preferred location. The application features a beautiful, modern design, real-time updates, and robust integration with our backend services.

## Table of Contents
- [Features](#features)
- [Technologies](#technologies)
- [Setup](#setup)
- [Environment Configuration](#environment-configuration)
- [Screens & Navigation](#screens--navigation)
- [Authentication & SMS Verification](#authentication--sms-verification)
- [Location & Maps](#location--maps)
- [Contributing](#contributing)
- [Context & AI Assistance](#context--ai-assistance)
- [License](#license)

## Features
- **Partner Discovery:**  
  - Explore nearby bars and restaurants with real-time geospatial data.
  - Beautifully designed partner cards with dynamic image loading from AWS S3 (secured via pre-signed URLs).
- **Dynamic Menus:**  
  - View and interact with menus that are updated in real time.
  - Smooth animations and responsive layouts with horizontally sliding cards.
- **User Authentication:**  
  - Supports Firebase phone authentication, Google Sign-In, Apple Sign-In, and Facebook Sign-In.
  - SMS verification with automatic code detection using `sms_autofill` and a customizable UI.
- **Location Integration:**  
  - Retrieves user location to filter nearby partners and calculate approximate distances.
  - Handles permission requests gracefully with `location` and `permission_handler`.
- **Theming & Customization:**  
  - Uses a custom color palette for a consistent look and feel:
    - **mainColor:** `Color(0xFF162A49)`
    - **backgroundColor2:** `Color(0xFF17203A)`
    - **backgroundColorLight:** `Color(0xFFF2F6FF)`
    - **backgroundColorDark:** `Color(0xFF25254B)`
    - **shadowColorLight:** `Color(0xFF4A5367)`
    - **shadowColorDark:** `Colors.black`
- **Clean Architecture:**  
  - Organized state management with Bloc.
  - Clear separation of UI, business logic, and data mapping (data models are transformed into UI models).

## Technologies
- **Framework:** [Flutter](https://flutter.dev/)
- **State Management:** [Bloc](https://bloclibrary.dev/)
- **Maps & Location:**  
  - [google_maps_flutter](https://pub.dev/packages/google_maps_flutter)
  - [location](https://pub.dev/packages/location)
  - [permission_handler](https://pub.dev/packages/permission_handler)
- **Authentication:** Firebase (phone auth, Google, Apple, Facebook)
- **SMS Autofill:** [sms_autofill](https://pub.dev/packages/sms_autofill)
- **Phone Input:** [phone_form_field](https://pub.dev/packages/phone_form_field)
- **Image Handling:** NetworkImage for displaying AWS S3 images via pre-signed URLs
- **Other Tools:**  
  - [Pinput](https://pub.dev/packages/pinput) for SMS code entry  
  - Custom UI widgets and theming components

## Setup

### Prerequisites
- Flutter SDK (latest stable release)
- A configured Firebase project for authentication
- Google Maps API key added to your iOS and Android configuration
- AWS S3 bucket configured for image storage (using pre-signed URLs for secure access)
- Simulator or physical devices for testing

### Installation
1. **Clone the repository:**
   ```bash
   git clone https://github.com/bl4ckcode/barz-frontend.git
   cd barz-frontend
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure your environment:**
   - For Android, update the API key in `android/app/src/main/AndroidManifest.xml`.
   - For iOS, add your Google Maps API key in `ios/Runner/AppDelegate.swift` (or retrieve it from `Info.plist` if you prefer).
   - Set up any necessary configuration files (e.g., for Firebase).

4. **Run the application:**
   ```bash
   flutter run
   ```

## Environment Configuration
Make sure you have configured:
- **Firebase:** Follow the Firebase setup instructions for Flutter.
- **Google Maps:**  
  - iOS: Ensure `GMSServices.provideAPIKey("YOUR_API_KEY")` is added in `AppDelegate.swift` or retrieved from `Info.plist`.  
  - Android: Add your API key in `AndroidManifest.xml` under the `<application>` tag.
- **AWS S3:** Pre-signed URLs are generated on the backend; your app will simply retrieve and display these URLs.

## Screens & Navigation
- **Home Screen:**  
  - Displays a horizontally sliding card list of nearby bars and restaurants.
  - Tapping a card triggers an event (via Bloc) to navigate to the detailed partner page.
- **Authentication Flow:**  
  - Phone login with SMS code verification (using Pinput and SMS autofill).
  - Custom phone input field using `phone_form_field` that respects our app's color palette.
- **Menus & Orders:**  
  - Real-time updates from the backend.
  - Clean separation between data models and UI models.

## Authentication & SMS Verification
- **Firebase Authentication:**  
  - Implements Firebase phone authentication along with Google, Apple, and Facebook Sign-In.
- **SMS Code Verification:**  
  - Uses `Pinput` for code entry with auto-validation and automatic code detection via the `sms_autofill` package.
  - Button is enabled only when the SMS code is fully entered (6 digits).
- **Bloc Architecture:**  
  - Authentication events trigger state changes, with error handling and success navigation.

## Location & Maps
- **Location Permissions:**  
  - Uses `location` and `permission_handler` to request and manage location permissions.
  - Retrieves current location and passes parameters to the backend for geospatial queries.
- **Google Maps Integration:**  
  - Embedded maps display partner locations and can calculate distances (using Haversine or similar formulas).

## Contributing
Contributions are welcome! Please follow these steps:
1. Fork the repository.
2. Create a new branch (`git checkout -b feature/YourFeatureName`).
3. Commit your changes (`git commit -m 'Add some feature'`).
4. Push to your branch (`git push origin feature/YourFeatureName`).
5. Open a pull request.

## Context & AI Assistance
This project was built with an innovative spirit and with assistance from AI (ChatGPT) to ensure adherence to best practices and modern Flutter architecture patterns. For further guidance or troubleshooting, please reference the detailed context below:

> **Prompt Example for AI Assistance:**  
> "I need help with the BarZ Frontend Flutter application. The project features real-time updates, dual-database architecture integration (via API), Firebase authentication, SMS autofill, and custom theming. How can I optimize the Bloc pattern for managing location permissions and SMS verification flows?"
  
Feel free to adapt the prompt to your specific needs.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

Made with ❤️ by [bl4ckcode](https://github.com/bl4ckcode)
