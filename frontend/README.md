# Purana Bazaar — Flutter app

Customer, shop-owner, admin and delivery-partner clients for the Purana Bazaar
marketplace. The backend lives in `../backend` (Spring Boot).

## Run

```bash
flutter pub get
flutter run -d chrome
```

The API URL defaults to `http://localhost:8080/api` (web/desktop) and
`http://10.0.2.2:8080/api` (Android emulator). Point it elsewhere with:

```bash
flutter run --dart-define=API_BASE_URL=http://<host>:8080/api
```

## Structure

```
lib/
├── main.dart / app.dart      Bootstrap, providers and role-based routing
├── core/                     API client, theme, formatters
├── models/                   API DTO models
├── state/                    Auth, cart, location and delivery providers
├── widgets/                  Shared cards, buttons, states
└── screens/
    ├── auth/                 Login, customer and shop-owner registration
    ├── home/ product/ shop/  Catalogue, Product Choice and Shop Choice
    ├── cart/ checkout/       Cart, checkout and confirmation
    ├── orders/               Order history and details
    ├── location/             Saved addresses
    ├── wishlist/ profile/    Wishlist and customer account
    ├── owner/                Shop-owner dashboard, orders, inventory, shop
    ├── admin/                Admin dashboard, shops, customers, catalogue, orders
    └── delivery/             Delivery partner overview, pickups, deliveries
```

## Demo accounts

| Role             | Email                       | Password      |
|------------------|-----------------------------|---------------|
| Customer         | `customer@puranabazaar.com` | `Customer@123` |
| Shop owner       | `sharma@puranabazaar.com`   | `Owner@123`    |
| Delivery partner | `delivery@puranabazaar.com` | `Delivery@123` |
| Admin            | `admin@puranabazaar.com`    | `Admin@123`    |

## Verify

```bash
flutter analyze
flutter test
```
