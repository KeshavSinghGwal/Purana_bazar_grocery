# Purana Bazaar

Purana Bazaar is a full-stack, multi-vendor neighbourhood grocery marketplace. Customers can shop by **Product Choice** (the backend finds the nearest eligible shop that can fulfil the whole cart) or by **Shop Choice** (the customer picks one shop and only that shop's inventory is used). Shop owners manage stock, prices and the order lifecycle, while administrators approve shops, moderate the catalog and oversee orders.

- **Backend:** Java 21, Spring Boot 4, Spring Security, Spring Data JPA, PostgreSQL, JWT, BCrypt, Razorpay REST API, Firebase Admin SDK
- **Frontend:** Flutter 3.44, Provider, `http`, `shared_preferences`, `intl`, Razorpay Checkout (web), Firebase Cloud Messaging
- **Design:** green-and-white, Blinkit-style responsive UI. No reference screenshot was supplied with the brief, so the visual system follows the written description.

---

## Repository layout

```
purana-bazaar/
├── backend/                 Spring Boot REST API
│   ├── src/main/java/       controllers, services, entities, security, seeding
│   ├── src/main/resources/  application.properties
│   └── src/test/java/       MarketplaceFlowIntegrationTest (12 scenarios)
├── frontend/                Flutter app
│   ├── lib/core/            API client, theme, formatters, Firebase/Razorpay adapters
│   ├── lib/models/          DTO models
│   ├── lib/services/        Payment and order API calls
│   ├── lib/state/           Auth, location, cart and notification providers
│   ├── lib/screens/         customer, owner and admin experiences
│   ├── lib/widgets/         shared UI components
│   ├── web/                 Razorpay JS bridge and FCM service worker
│   └── test/                model and formatter tests
└── .pgdata/                 local PostgreSQL 17 data directory (not source-controlled)
```

---

## What is implemented

### Customer
- Splash/session restore, login, customer registration, shop-owner registration
- Home with categories, featured products and nearby shops
- Search, product listing/detail, wishlist
- **Product Choice:** cart lines by `productId`; backend selects the nearest shop that can fulfil the complete cart
- **Shop Choice:** browse a shop's live inventory, add by `shopInventoryId`, single-shop enforcement
- Delivery address management with latitude/longitude
- Cart quantity controls, stock/availability warnings and mode conflict errors
- Checkout with address selection, **Cash on Delivery or Razorpay online payment**, order confirmation and idempotency key reuse
- Order history/details, retry payment for unpaid online orders, customer cancellation while the order is still cancellable
- In-app notification centre (bell + badge) and optional Firebase push notifications
- Reviews after a delivered order from that shop

### Shop owner
- Registration creates a shop in `PENDING_APPROVAL`; it stays hidden until approved
- Dashboard with sales, pending orders, listings and recent orders
- Shop profile editing, opening hours, delivery radius and open/closed toggle
- Inventory CRUD with owner-set prices and stock
- Owner order queue with guarded status transitions
- Sales history

### Administrator
- Dashboard with marketplace-wide counters
- Shop approval queue, approve/reject/suspend/reactivate
- Customer listing with suspend/reactivate
- All-orders view with filters, detail sheet and admin cancellation
- Catalog management for products and categories, including activation/deactivation

### Delivery partner
- Dedicated delivery workspace with dashboard counters, available pickups and active deliveries
- Delivery partners can accept a `READY_FOR_PICKUP` order, mark it `OUT_FOR_DELIVERY` and complete it as `DELIVERED`
- Completed deliveries update the order status, payment state and shop earnings

---

## Prerequisites

- Java 21 (`JAVA_HOME` must point at a JDK 21)
- Flutter 3.44+ / Dart 3.12+
- PostgreSQL 17
- Windows PowerShell examples below; equivalent commands work on macOS/Linux

The repository is already configured for a local PostgreSQL cluster on **port 5433** with databases:

- `purana_bazaar`
- `purana_bazaar_test`

### Start the local PostgreSQL cluster

```powershell
$env:PGDATA = 'D:\purana-bazaar\.pgdata'
& 'C:\Program Files\PostgreSQL\17\bin\pg_ctl.exe' -D $env:PGDATA -o '-p 5433' start
```

If the databases do not exist yet:

```powershell
& 'C:\Program Files\PostgreSQL\17\bin\createdb.exe' -h localhost -p 5433 -U postgres purana_bazaar
& 'C:\Program Files\PostgreSQL\17\bin\createdb.exe' -h localhost -p 5433 -U postgres purana_bazaar_test
```

The default development connection is `postgres` with an empty password. Override with `DB_USERNAME`, `DB_PASSWORD` and `DB_URL` if your cluster differs.

---

## Run the backend

```powershell
cd D:\purana-bazaar\backend
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.12'
.\mvnw.cmd spring-boot:run
```

The API starts on `http://localhost:8080`, health at `http://localhost:8080/actuator/health`.

If port 8080 is already occupied:

```powershell
$env:SERVER_PORT = '8081'
.\mvnw.cmd spring-boot:run
```

Run the backend integration suite:

```powershell
cd D:\purana-bazaar\backend
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.12'
.\mvnw.cmd test
```

The suite uses `purana_bazaar_test` and covers the scenarios listed at the end of this document.

### Demo data

When `app.seed.enabled=true` (the default), the seeder creates demo categories, products, shops, inventory and accounts. The catalog top-up is idempotent: restarting the backend adds any missing demo products/listings without overwriting owner or admin changes.

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@puranabazaar.com` | `Admin@123` |
| Customer | `customer@puranabazaar.com` | `Customer@123` |
| Shop owner | `sharma@puranabazaar.com` | `Owner@123` |
| Pending shop owner | `newshop@puranabazaar.com` | `Owner@123` |
| Delivery partner | `delivery@puranabazaar.com` | `Delivery@123` |

Other seeded owners (`gupta@`, `citymart@`, `freshbasket@`, `verma@`) also use `Owner@123`.

The seeded customer has **Home** and **Office** addresses in Indore. Sharma deliberately does **not** carry Basmati Rice 5kg or Aashirvaad Atta 5kg, so Product Choice carts containing those items fall through to the next eligible nearest shop. The catalog expansion adds roughly 30 more products across fresh produce, dairy, staples, snacks, beverages, personal care, household, frozen foods and baby care.

---

## Run the Flutter app

```powershell
cd D:\purana-bazaar\frontend
flutter pub get
.\run_web.ps1
```

`run_web.ps1` starts the app against `http://localhost:8081/api` by default and passes `--no-web-resources-cdn`, which is required on networks where `gstatic.com` is blocked. To point at another backend:

```powershell
$env:API_BASE_URL = 'http://localhost:8080/api'
.\run_web.ps1
```

Or run Flutter directly:

```powershell
flutter run -d chrome --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:8081/api
```

The built-in default API base is `http://localhost:8080/api` on web/desktop and `http://10.0.2.2:8080/api` on an Android emulator. This workspace runs the backend on port **8081** (port 8080 may be used by another process), so `run_web.ps1` defaults to `http://localhost:8081/api`.

> **Blank page fix:** by default Flutter downloads CanvasKit from `https://www.gstatic.com`. If that host is blocked, the renderer never starts and the browser shows a blank page. `--no-web-resources-cdn` makes Flutter serve CanvasKit from the local SDK instead; `run_web.ps1` includes it, and the release build command below does too.

Run static analysis and tests:

```powershell
flutter analyze
flutter test
```

Build a release web bundle:

```powershell
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:8081/api
```

Serve `frontend/build/web` with any static web server. CORS in the backend allows `http://localhost:*` and `http://127.0.0.1:*` by default.

> On Windows, `flutter pub get` may ask for **Developer Mode** because plugin builds use symbolic links. Enabling Developer Mode resolves that for desktop targets; the web build itself does not require it.

---

## Configuration

| Property | Env var | Default |
| --- | --- | --- |
| Server port | `SERVER_PORT` | `8080` |
| JDBC URL | `DB_URL` | `jdbc:postgresql://localhost:5433/purana_bazaar` |
| DB user | `DB_USERNAME` | `postgres` |
| DB password | `DB_PASSWORD` | empty |
| JWT secret | `JWT_SECRET` | local development secret |
| JWT lifetime | `JWT_EXPIRATION_MINUTES` | `1440` |
| Base delivery fee | `DELIVERY_BASE_FEE` | `19` |
| Free delivery threshold | `DELIVERY_FREE_ABOVE` | `199` |
| Demo seeding | `SEED_ENABLED` | `true` |
| CORS origins | `CORS_ORIGINS` | `http://localhost:*,http://127.0.0.1:*` |
| Business timezone | `app.timezone` | `Asia/Kolkata` |
| Razorpay key id | `RAZORPAY_KEY_ID` | empty |
| Razorpay key secret | `RAZORPAY_KEY_SECRET` | empty |
| Razorpay webhook secret | `RAZORPAY_WEBHOOK_SECRET` | empty |
| Razorpay local mock mode | `RAZORPAY_MOCK_ENABLED` | `false` |
| Unpaid online order timeout | `PAYMENT_PENDING_TIMEOUT_MINUTES` | `120` |
| FCM service account JSON | `FIREBASE_SERVICE_ACCOUNT_JSON` | empty |
| FCM service account file | `FIREBASE_SERVICE_ACCOUNT_FILE` | empty |
| FCM project id | `FIREBASE_PROJECT_ID` | derived from the service account |

**Important:** replace `JWT_SECRET` and use a real password in any non-local environment. `spring.jpa.hibernate.ddl-auto=update` is used for local development; production deployments should use versioned migrations (for example Flyway or Liquibase).

---

## Online payments (Razorpay)

Checkout accepts `COD` or `ONLINE`. An `ONLINE` order is created as `PAYMENT_PENDING` and its stock is reserved immediately; the app then creates a Razorpay order, opens Razorpay Checkout, and verifies the signature on the backend before the order moves to `PENDING` with payment status `PAID`. Failed or abandoned payments stay retryable from the order details screen, and unpaid orders are cancelled automatically after `PAYMENT_PENDING_TIMEOUT_MINUTES`, which releases the reserved stock. Cancelling or rejecting a paid order triggers a best-effort Razorpay refund.

### Configure live payments

1. Create a Razorpay account and copy the **Key ID** and **Key Secret** from *Dashboard → Account & Settings → API Keys*.
2. Export them before starting the backend:

   ```powershell
   $env:RAZORPAY_KEY_ID = 'rzp_live_...'
   $env:RAZORPAY_KEY_SECRET = '...'
   $env:RAZORPAY_WEBHOOK_SECRET = '...'
   ```

3. Add a webhook in *Dashboard → Account & Settings → Webhooks* pointing at
   `https://<your-host>/api/payments/razorpay/webhook` and subscribe to
   `payment.captured`, `payment.failed`, `order.paid` and `refund.processed`.
   The webhook secret must match `RAZORPAY_WEBHOOK_SECRET`.

The backend verifies `X-Razorpay-Signature` over the raw request body, so the
webhook remains the source of truth even if the browser closes before the
verification call. The frontend loads Razorpay's `checkout.js` on demand from
`https://checkout.razorpay.com/v1/checkout.js`, which must be reachable from the
customer's browser.

### Local mock mode

For local demos without Razorpay keys:

```powershell
$env:RAZORPAY_MOCK_ENABLED = 'true'
.\mvnw.cmd spring-boot:run
```

The backend creates `order_mock_*` sessions and accepts the signature `mock`.
The Flutter web app shows a **Razorpay test checkout** dialog instead of the
real Checkout window, so the complete order → pay → notification → refund flow
can be exercised offline. Mock mode is ignored when real keys are configured.

---

## Push notifications (Firebase Cloud Messaging)

Every order, payment, delivery and account event is written to the in-app
notification centre (`app_notifications`) and shown through the bell in the app.
Push delivery is optional and additive: without Firebase credentials the app and
the notification centre keep working, and the backend logs
`FCM is not configured`.

### Backend setup

1. Create a Firebase project and generate a service account key
   (*Project settings → Service accounts → Generate new private key*).
2. Provide the key in one of these forms before starting the backend:

   ```powershell
   # Raw JSON or base64-encoded JSON
   $env:FIREBASE_SERVICE_ACCOUNT_JSON = Get-Content .\service-account.json -Raw
   # ...or a path to the JSON file
   $env:FIREBASE_SERVICE_ACCOUNT_FILE = 'D:\secrets\service-account.json'
   # Optional when it cannot be inferred from the service account
   $env:FIREBASE_PROJECT_ID = 'your-project-id'
   ```

3. Restart the backend. `GET /api/notifications/unread-count` reports
   `pushEnabled: true` once Firebase Admin initialises.

### Flutter web setup

Supply the Firebase **Web app** config plus a Web Push certificate (VAPID key)
at build/run time. The values come from *Project settings → General → Your apps*
and *Cloud Messaging → Web Push certificates*:

```powershell
flutter run -d chrome --no-web-resources-cdn `
  --dart-define=API_BASE_URL=http://localhost:8081/api `
  --dart-define=FIREBASE_API_KEY=... `
  --dart-define=FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com `
  --dart-define=FIREBASE_PROJECT_ID=your-project `
  --dart-define=FIREBASE_STORAGE_BUCKET=your-project.firebasestorage.app `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
  --dart-define=FIREBASE_APP_ID=... `
  --dart-define=FIREBASE_VAPID_KEY=...
```

Replace the placeholders in `frontend/web/firebase-messaging-sw.js` with the same
web config so background pushes are displayed while the app is closed. Android
builds use the same `FIREBASE_*` dart-defines through `firebase_options.dart`,
and need `google-services.json` for the `firebase_messaging` plugin in a
production build. The app asks for notification permission on first run and
registers the resulting device token with `POST /api/notifications/devices`.

---

## API overview

All endpoints are under `/api`. Authenticated requests use:

```http
Authorization: Bearer <jwt>
Content-Type: application/json
```

### Authentication and account

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| POST | `/auth/register` | Public | Register a customer and return a session |
| POST | `/auth/login` | Public | Log in, return JWT + user + shop context |
| POST | `/auth/logout` | Authenticated | Stateless logout acknowledgement |
| GET | `/auth/me` | Authenticated | Current user, role, shop id/status |
| POST | `/shop-owner/register` | Public | Register owner + shop in `PENDING_APPROVAL` |
| GET | `/customers/profile` | Customer | Read profile |
| PUT | `/customers/profile` | Customer | Update name/phone |

### Addresses

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| GET | `/customers/addresses` | Customer | List own addresses |
| POST | `/customers/addresses` | Customer | Create address |
| PUT | `/customers/addresses/{id}` | Customer | Update own address |
| PUT | `/customers/addresses/{id}/default` | Customer | Set default address |
| DELETE | `/customers/addresses/{id}` | Customer | Delete own address |

### Catalog and marketplace

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| GET | `/categories` | Public | Active categories |
| GET | `/categories/{id}/products` | Public | Active products in a category |
| GET | `/marketplace/home` | Public | Categories, featured products, nearby shops |
| GET | `/marketplace/products` | Public | Paged/filterable product search |
| GET | `/marketplace/products/{id}` | Public | Product detail with availability |
| GET | `/marketplace/search` | Public | Combined product/category/shop search |
| POST | `/marketplace/find-shop` | Customer | Quote the nearest shop that can fulfil the cart |
| POST | `/marketplace/checkout/validate` | Customer | Revalidate cart and delivery before checkout |

`find-shop` accepts an `addressId`, or `latitude`/`longitude`, plus an optional explicit `items` list:

```json
{
  "addressId": 1,
  "items": [{ "productId": 14, "quantity": 2 }]
}
```

The response includes `found`, `message`, `selectedShop`, `distanceKm`, priced `items`, totals, `unavailableProducts` and per-candidate `consideredShops` reasons.

### Shops, inventory and reviews

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| GET | `/shops` | Public | Approved shops with optional search/geo/sort |
| GET | `/shops/nearby` | Public | Nearby approved shops |
| GET | `/shops/{id}` | Public | Shop detail |
| GET | `/shops/{id}/products` | Public | Shop's priced products |
| GET | `/shops/{id}/inventory` | Public | Shop's live listings, including `shopInventoryId` |
| GET | `/shops/{id}/categories` | Public | Categories carried by the shop |
| GET | `/shops/{id}/reviews` | Public | Shop reviews |
| POST | `/shops/{id}/reviews` | Customer | Create/update review after a delivered order |

### Cart

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| GET | `/cart` | Customer | Current cart with availability checks |
| POST | `/cart/items` | Customer | Add Product Choice or Shop Choice line |
| PUT | `/cart/items/{id}` | Customer | Change quantity |
| DELETE | `/cart/items/{id}` | Customer | Remove line |
| DELETE | `/cart` | Customer | Clear cart |

Product Choice:

```json
{ "shoppingMode": "PRODUCT_CHOICE", "productId": 14, "quantity": 2 }
```

Shop Choice:

```json
{ "shoppingMode": "SHOP_CHOICE", "shopInventoryId": 87, "quantity": 1 }
```

Mixing modes in one cart returns `CART_MODE_CONFLICT`; mixing shops in Shop Choice returns `MIXED_SHOP_CART`.

### Orders and payments

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| POST | `/orders` | Customer | Create order from the cart |
| GET | `/orders` | Customer | Own order history |
| GET | `/orders/{id}` | Customer | Own order detail |
| PUT | `/orders/{id}/cancel` | Customer | Cancel while cancellable, restore stock |

Checkout body:

```json
{
  "addressId": 1,
  "paymentMethod": "COD",
  "idempotencyKey": "checkout-2026-11-03-0001",
  "customerNote": "Leave at the door"
}
```

`idempotencyKey` must be 8–80 characters and is unique per customer. Replaying the same key returns the original order without deducting stock again. Set `paymentMethod` to `ONLINE` to pay through Razorpay; the order starts as `PAYMENT_PENDING` and is confirmed after signature verification.

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| POST | `/payments/razorpay/order` | Customer | Create/reuse a Razorpay order for an `ONLINE` order |
| POST | `/payments/razorpay/verify` | Customer | Verify the Checkout signature and mark the order paid |
| GET | `/payments/orders/{orderId}` | Customer | Payment status and whether the payment can be retried |
| POST | `/payments/razorpay/webhook` | Razorpay | Signature-verified payment/refund webhook |

### Notifications

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| GET | `/notifications` | Authenticated | Notification history, optional `unreadOnly=true` |
| GET | `/notifications/unread-count` | Authenticated | Unread badge count and `pushEnabled` flag |
| PUT | `/notifications/{id}/read` | Authenticated | Mark one notification read |
| PUT | `/notifications/read-all` | Authenticated | Mark every notification read |
| POST | `/notifications/devices` | Authenticated | Register an FCM device token |
| DELETE | `/notifications/devices?token=...` | Authenticated | Remove a device token |

### Wishlist

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| GET | `/wishlist` | Customer | Wishlist with full product summaries |
| POST | `/wishlist/{productId}` | Customer | Add product |
| DELETE | `/wishlist/{productId}` | Customer | Remove product |

### Shop-owner APIs

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/shop-owner/dashboard` | Shop metrics and recent orders |
| GET | `/shop-owner/shop` | Own shop profile |
| PUT | `/shop-owner/shop` | Update own shop |
| PUT | `/shop-owner/shop/open` | Toggle active/temporarily closed |
| GET | `/shop-owner/inventory` | Own listings |
| POST | `/shop-owner/inventory` | Add listing |
| PUT | `/shop-owner/inventory/{id}` | Update listing |
| DELETE | `/shop-owner/inventory/{id}` | Remove listing |
| GET | `/shop-owner/products/available` | Catalog products not yet listed |
| POST | `/shop-owner/products` | Create a catalog product |
| GET | `/shop-owner/orders` | Own shop orders, optional `status` |
| PUT | `/shop-owner/orders/{id}/status` | Advance/reject/cancel order |
| GET | `/shop-owner/sales` | Delivered-order sales history |

All owner operations are scoped to the authenticated owner's shop. Updating another shop's inventory or order returns `403`.

### Admin APIs

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/admin/dashboard` | Marketplace counters |
| GET | `/admin/shops` | All shops, optional `status` |
| GET | `/admin/shops/pending` | Approval queue |
| GET | `/admin/shops/{id}` | Shop detail |
| PUT | `/admin/shops/{id}/approve` | Approve |
| PUT | `/admin/shops/{id}/reject` | Reject with `{ "reason": "..." }` |
| PUT | `/admin/shops/{id}/suspend` | Suspend with reason |
| PUT | `/admin/shops/{id}/reactivate` | Reactivate |
| GET | `/admin/customers` | Customer list with order counts |
| PUT | `/admin/customers/{id}/suspend` | Disable customer login |
| PUT | `/admin/customers/{id}/reactivate` | Re-enable customer |
| GET | `/admin/orders` | All orders, optional `status`/`shopId` |
| GET | `/admin/orders/{id}` | Order detail |
| PUT | `/admin/orders/{id}/cancel` | Cancel and restore stock |
| GET/POST | `/admin/categories` | List/create categories |
| PUT/DELETE | `/admin/categories/{id}` | Update/deactivate category |
| GET/POST | `/admin/products` | Paged list/create products |
| PUT/DELETE | `/admin/products/{id}` | Update/deactivate product |

Catalog deletes are soft deactivations, so historical orders and inventory references remain intact.

### Error shape

```json
{
  "timestamp": "2026-11-03T10:15:30Z",
  "status": 400,
  "code": "VALIDATION_FAILED",
  "message": "Please correct the highlighted fields.",
  "path": "/api/auth/register",
  "details": null,
  "fieldErrors": { "email": "must be a well-formed email address" }
}
```

Common codes include `UNAUTHORIZED`, `FORBIDDEN`, `VALIDATION_FAILED`, `CART_EMPTY`, `CART_MODE_CONFLICT`, `MIXED_SHOP_CART`, `INSUFFICIENT_STOCK`, `OUT_OF_STOCK`, `NO_ELIGIBLE_SHOP`, `SHOP_CLOSED`, `OUTSIDE_DELIVERY_RADIUS`, `INVALID_STATUS_TRANSITION`, `CANCEL_NOT_ALLOWED`, `ORDER_NOT_FOUND`, `SHOP_NOT_FOUND`, `CONCURRENT_UPDATE`, `ONLINE_PAYMENT_NOT_CONFIGURED`, `NOT_AN_ONLINE_ORDER`, `PAYMENT_MISMATCH`, `PAYMENT_VERIFICATION_FAILED`, `PAYMENT_ALREADY_COMPLETED` and `PAYMENT_GATEWAY_ERROR`.

---

## Business rules

### Shop visibility and operation
- Public shop listings and ordering include only `APPROVED` shops with `ACTIVE` operational status.
- `PENDING_APPROVAL`, `REJECTED` and `SUSPENDED` shops are hidden from customers.
- A shop must be approved, active, delivery-enabled, currently open and within its delivery radius for an address before it can receive an order.
- One shop per owner is enforced by a unique `shops.owner_id` constraint.

### Product Choice
1. The customer adds catalog products by `productId`.
2. On quote/checkout the backend finds approved, active, open, delivery-enabled shops within radius of the selected address, ordered by straight-line Haversine distance.
3. The nearest shop that can satisfy **every** cart line in full is selected. Orders are never split across shops.
4. If no shop can fulfil the cart, the response contains `found: false`, a useful message, `unavailableProducts` with maximum available quantities and a reason for each considered shop.
5. Checkout re-runs the selection; the client cannot force a shop or supply trusted prices.

### Shop Choice
- The customer selects a shop and adds lines by `shopInventoryId`.
- Only that shop's active listings are considered; prices and stock come from the backend.
- A cart cannot mix Product Choice and Shop Choice lines, and cannot mix multiple shops.

### Pricing and stock
- The client never supplies prices. Order totals are recalculated from `shop_inventory`.
- Stock is reserved with pessimistic write locks after all lines validate, and decremented transactionally; overselling is rejected with `INSUFFICIENT_STOCK`/`OUT_OF_STOCK`.
- Delivery charge is a flat `₹19`, free when subtotal is at least `₹199`.
- Order items snapshot product name, brand, unit, image, price and line total.
- Cancellation/rejection restores stock once; the `stock_restored` flag makes this idempotent.
- Cart rows are cleared after successful order creation.

### Order lifecycle
Happy path:

```
PENDING → ACCEPTED → PREPARING → READY_FOR_PICKUP → OUT_FOR_DELIVERY → DELIVERED
```

Online orders begin at `PAYMENT_PENDING` and join the happy path at `PENDING` once payment is verified. A failed attempt can move to `PAYMENT_FAILED` and be retried. Alternative terminal states: `REJECTED` and `CANCELLED`.

Owner transitions:

| From | Allowed to |
| --- | --- |
| `PENDING` | `ACCEPTED`, `REJECTED`, `CANCELLED` |
| `ACCEPTED` | `PREPARING`, `CANCELLED` |
| `PREPARING` | `READY_FOR_PICKUP`, `CANCELLED` |
| `READY_FOR_PICKUP` | `OUT_FOR_DELIVERY` |
| `OUT_FOR_DELIVERY` | `DELIVERED` |

Customers can cancel while `PENDING`, `ACCEPTED`, `PREPARING` or `PAYMENT_PENDING`. Admin cancellation is allowed until the order is delivered/cancelled/rejected. COD orders start with payment status `PENDING`, become `PAID` on delivery, and become `FAILED` or `REFUNDED` if cancelled depending on prior payment state.

### Online payment rules
- Stock is reserved when the `ONLINE` order is created, not when payment succeeds, so a slow payment cannot lose the items.
- The Razorpay order id is bound to the order; verifying a payment against a different gateway order returns `PAYMENT_MISMATCH`.
- `POST /payments/razorpay/verify` checks the HMAC signature before marking the order `PAID` and moving it from `PAYMENT_PENDING` to `PENDING`.
- The webhook is idempotent and also handles `payment.failed` and refund events, in case the browser never calls verify.
- Unpaid online orders are cancelled by a scheduled job after `PAYMENT_PENDING_TIMEOUT_MINUTES`; reserved stock is restored and the payment is marked `FAILED`.
- Cancelling or rejecting a paid online order issues a best-effort refund; a gateway error is logged and never blocks the cancellation. Successful refunds set payment status `REFUNDED`.
- `ONLINE` checkout returns `ONLINE_PAYMENT_NOT_CONFIGURED` only when neither real Razorpay keys nor `RAZORPAY_MOCK_ENABLED=true` are present.

### Identity and isolation
- JWT is stateless; passwords are BCrypt-hashed.
- URL and method security enforce `CUSTOMER`, `SHOP_OWNER` and `ADMIN` boundaries; controller/service checks add ownership scoping.
- Customers can only read/cancel their own orders and addresses.
- Owners can only manage their own shop, inventory and orders.
- Admin APIs are restricted to `ADMIN`.
- Reviews require a delivered order from that shop; one review per customer/shop.

---

## Verification performed

- `flutter analyze` — no issues.
- `flutter test` — 15 tests passed (model parsing and formatters).
- `flutter build web --release` — succeeded.
- Backend `mvnw test` — 12 integration tests passed against PostgreSQL, including mock Razorpay payment, signature rejection, in-app notification read state and refund-on-cancel.
- Live API smoke checks against a running backend cover login, home, public shop inventory, admin dashboard, and the full Product Choice/Shop Choice checkout + cancellation path.

### Integration scenarios A–G

| Scenario | What is verified |
| --- | --- |
| **A** | The nearest shop with insufficient stock is skipped and the next nearest eligible shop fulfils the complete cart. |
| **B** | Shop Choice keeps the customer's chosen shop, uses its inventory, decrements stock and replays idempotently. |
| **C** | A newly registered shop stays hidden until an admin approves it. |
| **D** | Stock is decremented transactionally; requests above available stock are rejected and no overselling occurs. |
| **E** | A shop outside its delivery radius is never selected. |
| **F** | Cross-customer order access and cross-shop owner operations are denied; unauthenticated cart access returns 401. |
| **G** | When no shop can fulfil the cart, the response explains why and lists unavailable products with maximum available quantities. |
| **H** | Mock Razorpay checkout: stock is reserved while payment is pending, a bad signature is rejected, success moves the order to `PENDING`/`PAID`, notifications are created and readable, and cancellation refunds and restores stock. |

Additional integration coverage verifies the owner status lifecycle, invalid transition rejection, delivered COD payment state, cancellation stock restoration, and rejection of online payment attempts on COD orders.

---

## Assumptions and limitations

- The brief mentioned a reference screenshot but none was attached. The UI follows the described green/white, quick-commerce aesthetic and is fully responsive, but is not a pixel match to an unseen reference.
- Razorpay works with real keys or the built-in mock mode. Live mode requires an HTTPS webhook endpoint and Razorpay's `checkout.js` to be reachable from the customer's browser.
- Push notifications require Firebase credentials and, on web, a VAPID key and the configured service worker. Without them the in-app notification centre remains available.
- Delivery partners can accept and complete ready orders; automatic assignment/route optimisation and live GPS tracking are future work.
- Delivery distance is straight-line Haversine distance, not road-network distance.
- Delivery pricing is a single flat rule (`₹19`, free from `₹199`) rather than per-shop or distance-based slabs.
- Reviews are one per customer per shop and require a delivered order; they are editable by re-submitting.
- Demo seeding is for local development. The `ddl-auto=update` schema strategy and default JWT secret must not be used as-is in production.
- Images are remote Unsplash URLs. The Flutter image component shows a branded fallback if an image is unavailable.
