# dobar

Mobile application for dobar - a platform connecting users with bars, restaurants, and nightlife venues. Users can browse partners, view menus, place orders, and have items delivered to their table.

## Overview

dobar is built with Flutter using clean architecture principles. The app supports multiple payment gateways across different regions, real-time menu updates, and seamless authentication flows.

## Architecture

```
lib/
├── core/                    # Shared infrastructure
│   ├── api/                 # API client and endpoints
│   ├── error/               # Error handling (codes, exceptions, failures)
│   ├── network/             # Dio network layer
│   ├── storage/             # Local and secure storage
│   └── utils/               # Constants, extensions, DI
├── features/                # Feature modules
│   ├── authentication/      # Phone, Google, Apple, Facebook auth
│   ├── bars/                # Bar/venue browsing
│   ├── cart/                # Shopping cart
│   ├── home/                # Home feed
│   ├── location/            # Geolocation services
│   ├── menus/               # Menu display
│   ├── orders/              # Order management
│   ├── partners/            # Partner details
│   ├── payments/            # Payment processing
│   ├── promotions/          # Offers and promotions
│   └── user/                # User profile
└── shared/                  # Shared widgets and models
```

Each feature follows clean architecture:
- `data/` - Data sources, repositories implementation
- `domain/` - Models, repository interfaces, use cases
- `presentation/` - Bloc, pages, widgets

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.27+ |
| State Management | Bloc |
| Dependency Injection | GetIt |
| Network | Dio |
| Authentication | Firebase Auth |
| Maps | Google Maps Flutter |
| Code Generation | Freezed, JSON Serializable |

## Payment Gateways

| Region | Gateway | Methods |
|--------|---------|---------|
| Brazil | Pagar.me | Credit, Debit, PIX |
| Latin America | Stripe | Credit, Debit, Apple Pay, Google Pay |
| United States | Stripe | Credit, Debit, Apple Pay, Google Pay |
| Rest of World | PayPal | PayPal, Credit Card |

## Setup

### Prerequisites

- Flutter SDK 3.27.1+
- Xcode (for iOS)
- Android Studio (for Android)
- Firebase project configured
- Google Maps API key

### Installation

```bash
git clone https://github.com/bl4ckcode/barz.git
cd barz
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Configuration

1. Add Firebase configuration files:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

2. Configure Google Maps API key:
   - Android: `android/app/src/main/AndroidManifest.xml`
   - iOS: `ios/Runner/AppDelegate.swift`

### Running

```bash
flutter run
```

## Testing

```bash
# Run all tests
flutter test test/core/ test/features/

# Run specific test file
flutter test test/features/payments/payment_test.dart
```

## CI/CD

GitHub Actions workflow runs on push to `main`, `develop`, and `feat/**` branches:
- Installs dependencies
- Generates code (Freezed, JSON Serializable)
- Runs static analysis
- Executes unit tests

## Error Handling

The app implements a standardized error contract. See [API_ERROR_CONTRACT.md](API_ERROR_CONTRACT.md) for the complete specification.

Error codes are categorized by domain:
- General (network, server, validation)
- Authentication (session, token)
- Payment (declined, expired, insufficient funds)
- Order (not found, cancelled, expired)
- Location (permission denied, service disabled)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/name`)
3. Commit changes (`git commit -m 'Add feature'`)
4. Push to branch (`git push origin feature/name`)
5. Open a pull request

## License

Proprietary License. See [LICENSE](LICENSE) for details.
