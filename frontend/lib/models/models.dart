double _double(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? fallback;
}

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int _int(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

bool _bool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  return fallback;
}

String _string(dynamic value, [String fallback = '']) =>
    value == null ? fallback : '$value';

String? _stringOrNull(dynamic value) {
  if (value == null) return null;
  final text = '$value';
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse('$value')?.toLocal();

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? value.map((key, item) => MapEntry('$key', item)) : {};

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((item) => parse(_map(item))).toList();
}

String money(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.active,
    this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool active;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: _int(json['id']),
        name: _string(json['name']),
        email: _string(json['email']),
        phone: _stringOrNull(json['phone']),
        role: _string(json['role'], 'CUSTOMER'),
        active: _bool(json['active'], true),
        createdAt: _date(json['createdAt']),
      );

  bool get isCustomer => role == 'CUSTOMER';
  bool get isOwner => role == 'SHOP_OWNER';
  bool get isAdmin => role == 'ADMIN';
  bool get isDeliveryPartner => role == 'DELIVERY_PARTNER';
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.shopId,
    this.shopStatus,
  });

  final String token;
  final User user;
  final int? shopId;
  final String? shopStatus;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: _string(json['token']),
        user: User.fromJson(_map(json['user'])),
        shopId: json['shopId'] == null ? null : _int(json['shopId']),
        shopStatus: _stringOrNull(json['shopStatus']),
      );
}

class AccountInfo {
  const AccountInfo({required this.user, this.shopId, this.shopStatus});

  final User user;
  final int? shopId;
  final String? shopStatus;

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
        user: User.fromJson(_map(json['user'])),
        shopId: json['shopId'] == null ? null : _int(json['shopId']),
        shopStatus: _stringOrNull(json['shopStatus']),
      );
}

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
    required this.formattedAddress,
  });

  final int id;
  final String label;
  final String addressLine;
  final String city;
  final String state;
  final String postalCode;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final String formattedAddress;

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: _int(json['id']),
        label: _string(json['label'], 'Home'),
        addressLine: _string(json['addressLine']),
        city: _string(json['city']),
        state: _string(json['state']),
        postalCode: _string(json['postalCode']),
        latitude: _double(json['latitude']),
        longitude: _double(json['longitude']),
        isDefault: _bool(json['isDefault']),
        formattedAddress: _string(json['formattedAddress']),
      );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.active,
    required this.displayOrder,
  });

  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final bool active;
  final int displayOrder;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: _int(json['id']),
        name: _string(json['name']),
        description: _stringOrNull(json['description']),
        imageUrl: _stringOrNull(json['imageUrl']),
        active: _bool(json['active'], true),
        displayOrder: _int(json['displayOrder']),
      );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    this.description,
    this.brand,
    required this.categoryId,
    required this.categoryName,
    this.imageUrl,
    required this.unit,
    required this.active,
    this.bestPrice,
    required this.availableShops,
    required this.totalStock,
  });

  final int id;
  final String name;
  final String? description;
  final String? brand;
  final int categoryId;
  final String categoryName;
  final String? imageUrl;
  final String unit;
  final bool active;
  final double? bestPrice;
  final int availableShops;
  final int totalStock;

  bool get available => bestPrice != null && availableShops > 0 && totalStock > 0;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: _int(json['id']),
        name: _string(json['name']),
        description: _stringOrNull(json['description']),
        brand: _stringOrNull(json['brand']),
        categoryId: _int(json['categoryId']),
        categoryName: _string(json['categoryName']),
        imageUrl: _stringOrNull(json['imageUrl']),
        unit: _string(json['unit']),
        active: _bool(json['active'], true),
        bestPrice: _doubleOrNull(json['bestPrice']),
        availableShops: _int(json['availableShops']),
        totalStock: _int(json['totalStock']),
      );
}

class Shop {
  const Shop({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.openingTime,
    required this.closingTime,
    required this.deliveryRadius,
    required this.deliveryAvailable,
    required this.estimatedDeliveryMinutes,
    required this.approvalStatus,
    required this.operationalStatus,
    this.shopCategory,
    this.imageUrl,
    this.phone,
    this.distanceKm,
    required this.deliverable,
    required this.openNow,
    this.rating,
    required this.reviewCount,
    this.rejectionReason,
    this.createdAt,
  });

  final int id;
  final int ownerId;
  final String ownerName;
  final String name;
  final String? description;
  final String address;
  final double latitude;
  final double longitude;
  final String openingTime;
  final String closingTime;
  final double deliveryRadius;
  final bool deliveryAvailable;
  final int estimatedDeliveryMinutes;
  final String approvalStatus;
  final String operationalStatus;
  final String? shopCategory;
  final String? imageUrl;
  final String? phone;
  final double? distanceKm;
  final bool deliverable;
  final bool openNow;
  final double? rating;
  final int reviewCount;
  final String? rejectionReason;
  final DateTime? createdAt;

  bool get isActive => approvalStatus == 'APPROVED' && operationalStatus == 'ACTIVE';
  bool get isPending => approvalStatus == 'PENDING_APPROVAL';

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: _int(json['id']),
        ownerId: _int(json['ownerId']),
        ownerName: _string(json['ownerName']),
        name: _string(json['name']),
        description: _stringOrNull(json['description']),
        address: _string(json['address']),
        latitude: _double(json['latitude']),
        longitude: _double(json['longitude']),
        openingTime: _string(json['openingTime'], '06:00:00'),
        closingTime: _string(json['closingTime'], '23:59:00'),
        deliveryRadius: _double(json['deliveryRadius']),
        deliveryAvailable: _bool(json['deliveryAvailable'], true),
        estimatedDeliveryMinutes: _int(json['estimatedDeliveryMinutes'], 30),
        approvalStatus: _string(json['approvalStatus'], 'APPROVED'),
        operationalStatus: _string(json['operationalStatus'], 'ACTIVE'),
        shopCategory: _stringOrNull(json['shopCategory']),
        imageUrl: _stringOrNull(json['imageUrl']),
        phone: _stringOrNull(json['phone']),
        distanceKm: _doubleOrNull(json['distanceKm']),
        deliverable: _bool(json['deliverable'], true),
        openNow: _bool(json['openNow'], true),
        rating: _doubleOrNull(json['rating']),
        reviewCount: _int(json['reviewCount']),
        rejectionReason: _stringOrNull(json['rejectionReason']),
        createdAt: _date(json['createdAt']),
      );
}

class QuoteLine {
  const QuoteLine({
    required this.productId,
    required this.name,
    this.brand,
    required this.unit,
    this.imageUrl,
    required this.requestedQuantity,
    required this.availableQuantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final int productId;
  final String name;
  final String? brand;
  final String unit;
  final String? imageUrl;
  final int requestedQuantity;
  final int availableQuantity;
  final double unitPrice;
  final double lineTotal;

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
        productId: _int(json['productId']),
        name: _string(json['name']),
        brand: _stringOrNull(json['brand']),
        unit: _string(json['unit']),
        imageUrl: _stringOrNull(json['imageUrl']),
        requestedQuantity: _int(json['requestedQuantity']),
        availableQuantity: _int(json['availableQuantity']),
        unitPrice: _double(json['unitPrice']),
        lineTotal: _double(json['lineTotal']),
      );
}

class UnavailableProduct {
  const UnavailableProduct({
    required this.productId,
    required this.name,
    required this.requestedQuantity,
    required this.maxAvailable,
  });

  final int productId;
  final String name;
  final int requestedQuantity;
  final int maxAvailable;

  factory UnavailableProduct.fromJson(Map<String, dynamic> json) => UnavailableProduct(
        productId: _int(json['productId']),
        name: _string(json['name']),
        requestedQuantity: _int(json['requestedQuantity']),
        maxAvailable: _int(json['maxAvailable']),
      );
}

class ShopCandidate {
  const ShopCandidate({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.eligible,
    this.reason,
  });

  final int id;
  final String name;
  final double distanceKm;
  final bool eligible;
  final String? reason;

  factory ShopCandidate.fromJson(Map<String, dynamic> json) => ShopCandidate(
        id: _int(json['id']),
        name: _string(json['name']),
        distanceKm: _double(json['distanceKm']),
        eligible: _bool(json['eligible']),
        reason: _stringOrNull(json['reason']),
      );
}

class ShopQuote {
  const ShopQuote({
    required this.found,
    this.message,
    this.selectedShop,
    this.distanceKm,
    required this.items,
    required this.subtotal,
    required this.deliveryCharge,
    required this.totalAmount,
    required this.unavailableProducts,
    required this.consideredShops,
  });

  final bool found;
  final String? message;
  final Shop? selectedShop;
  final double? distanceKm;
  final List<QuoteLine> items;
  final double subtotal;
  final double deliveryCharge;
  final double totalAmount;
  final List<UnavailableProduct> unavailableProducts;
  final List<ShopCandidate> consideredShops;

  factory ShopQuote.fromJson(Map<String, dynamic> json) => ShopQuote(
        found: _bool(json['found']),
        message: _stringOrNull(json['message']),
        selectedShop: json['selectedShop'] == null
            ? null
            : Shop.fromJson(_map(json['selectedShop'])),
        distanceKm: _doubleOrNull(json['distanceKm']),
        items: _list(json['items'], QuoteLine.fromJson),
        subtotal: _double(json['subtotal']),
        deliveryCharge: _double(json['deliveryCharge']),
        totalAmount: _double(json['totalAmount']),
        unavailableProducts:
            _list(json['unavailableProducts'], UnavailableProduct.fromJson),
        consideredShops: _list(json['consideredShops'], ShopCandidate.fromJson),
      );
}

class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    this.shopInventoryId,
    this.shopId,
    required this.name,
    this.brand,
    required this.unit,
    this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.availableQuantity,
    required this.available,
    required this.categoryId,
    required this.categoryName,
  });

  final int id;
  final int productId;
  final int? shopInventoryId;
  final int? shopId;
  final String name;
  final String? brand;
  final String unit;
  final String? imageUrl;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final int availableQuantity;
  final bool available;
  final int categoryId;
  final String categoryName;

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: _int(json['id']),
        productId: _int(json['productId']),
        shopInventoryId:
            json['shopInventoryId'] == null ? null : _int(json['shopInventoryId']),
        shopId: json['shopId'] == null ? null : _int(json['shopId']),
        name: _string(json['name']),
        brand: _stringOrNull(json['brand']),
        unit: _string(json['unit']),
        imageUrl: _stringOrNull(json['imageUrl']),
        quantity: _int(json['quantity']),
        unitPrice: _double(json['unitPrice']),
        lineTotal: _double(json['lineTotal']),
        availableQuantity: _int(json['availableQuantity']),
        available: _bool(json['available'], true),
        categoryId: _int(json['categoryId']),
        categoryName: _string(json['categoryName']),
      );
}

class Cart {
  const Cart({
    this.id,
    this.shoppingMode,
    this.selectedShop,
    required this.items,
    required this.itemCount,
    required this.subtotal,
    required this.estimatedDeliveryCharge,
    required this.estimatedTotal,
    required this.hasAvailabilityIssues,
    this.notice,
  });

  final int? id;
  final String? shoppingMode;
  final Shop? selectedShop;
  final List<CartItem> items;
  final int itemCount;
  final double subtotal;
  final double estimatedDeliveryCharge;
  final double estimatedTotal;
  final bool hasAvailabilityIssues;
  final String? notice;

  bool get isEmpty => items.isEmpty;
  bool get isProductChoice => shoppingMode == 'PRODUCT_CHOICE';
  bool get isShopChoice => shoppingMode == 'SHOP_CHOICE';

  static const empty = Cart(
    items: [],
    itemCount: 0,
    subtotal: 0,
    estimatedDeliveryCharge: 0,
    estimatedTotal: 0,
    hasAvailabilityIssues: false,
  );

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
        id: json['id'] == null ? null : _int(json['id']),
        shoppingMode: _stringOrNull(json['shoppingMode']),
        selectedShop: json['selectedShop'] == null
            ? null
            : Shop.fromJson(_map(json['selectedShop'])),
        items: _list(json['items'], CartItem.fromJson),
        itemCount: _int(json['itemCount']),
        subtotal: _double(json['subtotal']),
        estimatedDeliveryCharge: _double(json['estimatedDeliveryCharge']),
        estimatedTotal: _double(json['estimatedTotal']),
        hasAvailabilityIssues: _bool(json['hasAvailabilityIssues']),
        notice: _stringOrNull(json['notice']),
      );
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.brand,
    required this.unit,
    this.imageUrl,
    required this.price,
    required this.quantity,
    required this.totalPrice,
  });

  final int id;
  final int productId;
  final String productName;
  final String? brand;
  final String unit;
  final String? imageUrl;
  final double price;
  final int quantity;
  final double totalPrice;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: _int(json['id']),
        productId: _int(json['productId']),
        productName: _string(json['productName']),
        brand: _stringOrNull(json['brand']),
        unit: _string(json['unit']),
        imageUrl: _stringOrNull(json['imageUrl']),
        price: _double(json['price']),
        quantity: _int(json['quantity']),
        totalPrice: _double(json['totalPrice']),
      );
}

class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.shoppingMode,
    required this.orderStatus,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.shop,
    required this.customerName,
    this.customerPhone,
    this.deliveryPartnerName,
    this.deliveryPartnerPhone,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.subtotal,
    required this.deliveryCharge,
    required this.totalAmount,
    required this.items,
    this.customerNote,
    this.cancellationReason,
    required this.canCancel,
    this.createdAt,
    this.updatedAt,
    this.paymentReference,
    this.paymentGateway,
    this.canRetryPayment = false,
  });

  final int id;
  final String orderNumber;
  final String shoppingMode;
  final String orderStatus;
  final String paymentStatus;
  final String paymentMethod;
  final Shop shop;
  final String customerName;
  final String? customerPhone;
  final String? deliveryPartnerName;
  final String? deliveryPartnerPhone;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final double subtotal;
  final double deliveryCharge;
  final double totalAmount;
  final List<OrderItem> items;
  final String? customerNote;
  final String? cancellationReason;
  final bool canCancel;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? paymentReference;
  final String? paymentGateway;
  final bool canRetryPayment;

  bool get isDelivered => orderStatus == 'DELIVERED';
  bool get isCancelled => orderStatus == 'CANCELLED' || orderStatus == 'REJECTED';
  bool get isAwaitingPayment =>
      orderStatus == 'PAYMENT_PENDING' || orderStatus == 'PAYMENT_FAILED';

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: _int(json['id']),
        orderNumber: _string(json['orderNumber']),
        shoppingMode: _string(json['shoppingMode']),
        orderStatus: _string(json['orderStatus']),
        paymentStatus: _string(json['paymentStatus']),
        paymentMethod: _string(json['paymentMethod']),
        shop: Shop.fromJson(_map(json['shop'])),
        customerName: _string(json['customerName']),
        customerPhone: _stringOrNull(json['customerPhone']),
        deliveryPartnerName: _stringOrNull(json['deliveryPartnerName']),
        deliveryPartnerPhone: _stringOrNull(json['deliveryPartnerPhone']),
        deliveryAddress: _string(json['deliveryAddress']),
        deliveryLatitude: _double(json['deliveryLatitude']),
        deliveryLongitude: _double(json['deliveryLongitude']),
        subtotal: _double(json['subtotal']),
        deliveryCharge: _double(json['deliveryCharge']),
        totalAmount: _double(json['totalAmount']),
        items: _list(json['items'], OrderItem.fromJson),
        customerNote: _stringOrNull(json['customerNote']),
        cancellationReason: _stringOrNull(json['cancellationReason']),
        canCancel: _bool(json['canCancel']),
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        paymentReference: _stringOrNull(json['paymentReference']),
        paymentGateway: _stringOrNull(json['paymentGateway']),
        canRetryPayment: _bool(json['canRetryPayment']),
      );
}

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.orderId,
    this.orderNumber,
    required this.read,
    this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final String type;
  final int? orderId;
  final String? orderNumber;
  final bool read;
  final DateTime? createdAt;

  AppNotificationItem copyWith({bool? read}) => AppNotificationItem(
        id: id,
        title: title,
        body: body,
        type: type,
        orderId: orderId,
        orderNumber: orderNumber,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) =>
      AppNotificationItem(
        id: _int(json['id']),
        title: _string(json['title']),
        body: _string(json['body']),
        type: _string(json['type']),
        orderId: json['orderId'] == null ? null : _int(json['orderId']),
        orderNumber: _stringOrNull(json['orderNumber']),
        read: _bool(json['read']),
        createdAt: _date(json['createdAt']),
      );
}

class Review {
  const Review({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  final int id;
  final int customerId;
  final String customerName;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: _int(json['id']),
        customerId: _int(json['customerId']),
        customerName: _string(json['customerName']),
        rating: _int(json['rating']),
        comment: _stringOrNull(json['comment']),
        createdAt: _date(json['createdAt']),
      );
}

class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.product,
    this.createdAt,
  });

  final int id;
  final Product product;
  final DateTime? createdAt;

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
        id: _int(json['id']),
        product: Product.fromJson(_map(json['product'])),
        createdAt: _date(json['createdAt']),
      );
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.brand,
    required this.unit,
    this.imageUrl,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    required this.availableQuantity,
    required this.active,
    this.updatedAt,
  });

  final int id;
  final int productId;
  final String productName;
  final String? brand;
  final String unit;
  final String? imageUrl;
  final int categoryId;
  final String categoryName;
  final double price;
  final int availableQuantity;
  final bool active;
  final DateTime? updatedAt;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: _int(json['id']),
        productId: _int(json['productId']),
        productName: _string(json['productName']),
        brand: _stringOrNull(json['brand']),
        unit: _string(json['unit']),
        imageUrl: _stringOrNull(json['imageUrl']),
        categoryId: _int(json['categoryId']),
        categoryName: _string(json['categoryName']),
        price: _double(json['price']),
        availableQuantity: _int(json['availableQuantity']),
        active: _bool(json['active'], true),
        updatedAt: _date(json['updatedAt']),
      );
}

class HomeData {
  const HomeData({
    required this.categories,
    required this.featuredProducts,
    required this.nearbyShops,
    required this.totalShops,
    required this.totalProducts,
  });

  final List<Category> categories;
  final List<Product> featuredProducts;
  final List<Shop> nearbyShops;
  final int totalShops;
  final int totalProducts;

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
        categories: _list(json['categories'], Category.fromJson),
        featuredProducts: _list(json['featuredProducts'], Product.fromJson),
        nearbyShops: _list(json['nearbyShops'], Shop.fromJson),
        totalShops: _int(json['totalShops']),
        totalProducts: _int(json['totalProducts']),
      );
}

class SearchResults {
  const SearchResults({
    required this.query,
    required this.products,
    required this.categories,
    required this.shops,
  });

  final String query;
  final List<Product> products;
  final List<Category> categories;
  final List<Shop> shops;

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
        query: _string(json['query']),
        products: _list(json['products'], Product.fromJson),
        categories: _list(json['categories'], Category.fromJson),
        shops: _list(json['shops'], Shop.fromJson),
      );
}

class OwnerDashboard {
  const OwnerDashboard({
    required this.shopId,
    required this.shopName,
    required this.approvalStatus,
    required this.operationalStatus,
    required this.address,
    required this.totalProducts,
    required this.outOfStockProducts,
    required this.totalOrders,
    required this.pendingOrders,
    required this.deliveredOrders,
    required this.totalSales,
    required this.recentOrders,
  });

  final int shopId;
  final String shopName;
  final String approvalStatus;
  final String operationalStatus;
  final String address;
  final int totalProducts;
  final int outOfStockProducts;
  final int totalOrders;
  final int pendingOrders;
  final int deliveredOrders;
  final double totalSales;
  final List<Order> recentOrders;

  factory OwnerDashboard.fromJson(Map<String, dynamic> json) => OwnerDashboard(
        shopId: _int(json['shopId']),
        shopName: _string(json['shopName']),
        approvalStatus: _string(json['approvalStatus']),
        operationalStatus: _string(json['operationalStatus']),
        address: _string(json['address']),
        totalProducts: _int(json['totalProducts']),
        outOfStockProducts: _int(json['outOfStockProducts']),
        totalOrders: _int(json['totalOrders']),
        pendingOrders: _int(json['pendingOrders']),
        deliveredOrders: _int(json['deliveredOrders']),
        totalSales: _double(json['totalSales']),
        recentOrders: _list(json['recentOrders'], Order.fromJson),
      );
}

class SalesHistory {
  const SalesHistory({
    required this.shopId,
    required this.shopName,
    required this.totalSales,
    required this.deliveredOrders,
    required this.orders,
  });

  final int shopId;
  final String shopName;
  final double totalSales;
  final int deliveredOrders;
  final List<Order> orders;

  factory SalesHistory.fromJson(Map<String, dynamic> json) => SalesHistory(
        shopId: _int(json['shopId']),
        shopName: _string(json['shopName']),
        totalSales: _double(json['totalSales']),
        deliveredOrders: _int(json['deliveredOrders']),
        orders: _list(json['orders'], Order.fromJson),
      );
}

class DeliveryDashboard {
  const DeliveryDashboard({
    required this.partnerName,
    required this.availableOrders,
    required this.activeDeliveries,
    required this.completedDeliveries,
    required this.totalDeliveryFees,
    required this.activeOrders,
  });

  final String partnerName;
  final int availableOrders;
  final int activeDeliveries;
  final int completedDeliveries;
  final double totalDeliveryFees;
  final List<Order> activeOrders;

  factory DeliveryDashboard.fromJson(Map<String, dynamic> json) => DeliveryDashboard(
        partnerName: _string(json['partnerName']),
        availableOrders: _int(json['availableOrders']),
        activeDeliveries: _int(json['activeDeliveries']),
        completedDeliveries: _int(json['completedDeliveries']),
        totalDeliveryFees: _double(json['totalDeliveryFees']),
        activeOrders: _list(json['activeOrders'], Order.fromJson),
      );
}

class AdminDashboard {
  const AdminDashboard({
    required this.totalShops,
    required this.approvedShops,
    required this.pendingShops,
    required this.suspendedShops,
    required this.totalCustomers,
    required this.activeCustomers,
    required this.totalProducts,
    required this.totalCategories,
    required this.totalOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.totalSales,
  });

  final int totalShops;
  final int approvedShops;
  final int pendingShops;
  final int suspendedShops;
  final int totalCustomers;
  final int activeCustomers;
  final int totalProducts;
  final int totalCategories;
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double totalSales;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) => AdminDashboard(
        totalShops: _int(json['totalShops']),
        approvedShops: _int(json['approvedShops']),
        pendingShops: _int(json['pendingShops']),
        suspendedShops: _int(json['suspendedShops']),
        totalCustomers: _int(json['totalCustomers']),
        activeCustomers: _int(json['activeCustomers']),
        totalProducts: _int(json['totalProducts']),
        totalCategories: _int(json['totalCategories']),
        totalOrders: _int(json['totalOrders']),
        pendingOrders: _int(json['pendingOrders']),
        completedOrders: _int(json['completedOrders']),
        cancelledOrders: _int(json['cancelledOrders']),
        totalSales: _double(json['totalSales']),
      );
}

class AdminCustomer {
  const AdminCustomer({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.active,
    this.createdAt,
    required this.orderCount,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final bool active;
  final DateTime? createdAt;
  final int orderCount;

  factory AdminCustomer.fromJson(Map<String, dynamic> json) => AdminCustomer(
        id: _int(json['id']),
        name: _string(json['name']),
        email: _string(json['email']),
        phone: _stringOrNull(json['phone']),
        active: _bool(json['active'], true),
        createdAt: _date(json['createdAt']),
        orderCount: _int(json['orderCount']),
      );
}
