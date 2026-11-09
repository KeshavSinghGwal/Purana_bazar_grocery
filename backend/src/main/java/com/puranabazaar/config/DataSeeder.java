package com.puranabazaar.config;

import com.puranabazaar.address.CustomerAddress;
import com.puranabazaar.address.CustomerAddressRepository;
import com.puranabazaar.catalog.Category;
import com.puranabazaar.catalog.CategoryRepository;
import com.puranabazaar.catalog.Product;
import com.puranabazaar.catalog.ProductRepository;
import com.puranabazaar.inventory.ShopInventory;
import com.puranabazaar.inventory.ShopInventoryRepository;
import com.puranabazaar.shop.*;
import com.puranabazaar.user.Role;
import com.puranabazaar.user.User;
import com.puranabazaar.user.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalTime;
import java.util.*;

@Component
public class DataSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);

    private final boolean enabled;
    private final UserRepository userRepository;
    private final ShopRepository shopRepository;
    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final ShopInventoryRepository inventoryRepository;
    private final CustomerAddressRepository addressRepository;
    private final PasswordEncoder passwordEncoder;

    public DataSeeder(@Value("${app.seed.enabled:true}") boolean enabled,
                      UserRepository userRepository, ShopRepository shopRepository,
                      CategoryRepository categoryRepository, ProductRepository productRepository,
                      ShopInventoryRepository inventoryRepository, CustomerAddressRepository addressRepository,
                      PasswordEncoder passwordEncoder) {
        this.enabled = enabled;
        this.userRepository = userRepository;
        this.shopRepository = shopRepository;
        this.categoryRepository = categoryRepository;
        this.productRepository = productRepository;
        this.inventoryRepository = inventoryRepository;
        this.addressRepository = addressRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (!enabled) {
            return;
        }
        if (userRepository.count() > 0) {
            ensureCatalogExpansion();
            ensureDeliveryPartner();
            return;
        }
        log.info("Seeding Purana Bazaar demo data...");

        User admin = user("Purana Bazaar Admin", "admin@puranabazaar.com", "9000000001",
                "Admin@123", Role.ADMIN);
        User customer = user("Aarav Sharma", "customer@puranabazaar.com", "9000000002",
                "Customer@123", Role.CUSTOMER);
        user("Ravi Kumar", "delivery@puranabazaar.com", "9000000003",
                "Delivery@123", Role.DELIVERY_PARTNER);

        Map<String, Category> categories = seedCategories();
        Map<String, Product> products = seedProducts(categories);

        Shop sharma = shop("Sharma General Store", "sharma@puranabazaar.com", "Rajesh Sharma",
                "Your trusted neighbourhood kirana store since 1998. Fresh dairy, staples and daily essentials.",
                "12, Scheme No. 54, Vijay Nagar, Indore, Madhya Pradesh", 22.7550, 75.8960,
                5.0, "Kirana", "https://images.unsplash.com/photo-1542838132-92c53300491e?w=1200&q=80",
                "https://images.unsplash.com/photo-1542838132-92c53300491e?w=1200&q=80", "0731-4001001",
                ShopApprovalStatus.APPROVED, 18);
        Shop gupta = shop("Gupta Grocery Store", "gupta@puranabazaar.com", "Sunil Gupta",
                "Family-run grocery store with everyday low prices and quick local delivery.",
                "45, Sapna Sangeeta Road, Indore, Madhya Pradesh", 22.7460, 75.8840,
                5.0, "Grocery", "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=1200&q=80",
                "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=1200&q=80", "0731-4001002",
                ShopApprovalStatus.APPROVED, 25);
        Shop cityMart = shop("City Mart", "citymart@puranabazaar.com", "Neha Jain",
                "A modern supermarket for groceries, fresh produce and household essentials.",
                "8, MG Road, Indore, Madhya Pradesh", 22.7400, 75.8700,
                6.0, "Supermarket", "https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=1200&q=80",
                "https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=1200&q=80", "0731-4001003",
                ShopApprovalStatus.APPROVED, 32);
        Shop freshBasket = shop("Fresh Basket", "freshbasket@puranabazaar.com", "Karan Mehta",
                "Fresh fruits, vegetables and daily essentials sourced from local farms.",
                "22, Bicholi Mardana Main Road, Indore, Madhya Pradesh", 22.7650, 75.9100,
                6.0, "Fresh Produce", "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=1200&q=80",
                "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=1200&q=80", "0731-4001004",
                ShopApprovalStatus.APPROVED, 28);
        Shop verma = shop("Verma Supermarket", "verma@puranabazaar.com", "Anil Verma",
                "Large-format supermarket with a wide range of groceries and household products.",
                "101, Ring Road, Khajrana, Indore, Madhya Pradesh", 22.7200, 75.8500,
                8.0, "Supermarket", "https://images.unsplash.com/photo-1583258292688-d0213dc5a3a8?w=1200&q=80",
                "https://images.unsplash.com/photo-1583258292688-d0213dc5a3a8?w=1200&q=80", "0731-4001005",
                ShopApprovalStatus.APPROVED, 35);

        User pendingOwner = user("Pooja Rathore", "newshop@puranabazaar.com", "9000000009",
                "Owner@123", Role.SHOP_OWNER);
        Shop pending = new Shop();
        pending.setOwner(pendingOwner);
        pending.setName("Pooja Fresh Kirana");
        pending.setDescription("Newly registered neighbourhood store awaiting verification.");
        pending.setAddress("77, Bhawarkua Main Road, Indore, Madhya Pradesh");
        pending.setLatitude(22.7500);
        pending.setLongitude(75.9000);
        pending.setOpeningTime(LocalTime.of(7, 0));
        pending.setClosingTime(LocalTime.of(22, 0));
        pending.setDeliveryRadius(4.0);
        pending.setShopCategory("Kirana");
        pending.setPhone("9000000009");
        pending.setImageUrl("https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=1200&q=80");
        pending.setApprovalStatus(ShopApprovalStatus.PENDING_APPROVAL);
        shopRepository.save(pending);

        seedInventory(sharma, products, 1.05, Map.of(
                "Basmati Rice 5kg", 0, "Aashirvaad Atta 5kg", 0,
                "Amul Taaza Toned Milk 1L", 4, "Farm Eggs 12 pcs", 3));
        seedInventory(gupta, products, 0.98, Map.of(
                "Farm Eggs 12 pcs", 6));
        seedInventory(cityMart, products, 1.03, Map.of(
                "Basmati Rice 5kg", 8, "Tropicana Orange Juice 1L", 0));
        seedInventory(freshBasket, products, 1.00, Map.of(
                "Aashirvaad Atta 5kg", 0, "Lay's Classic Salted 90g", 0));
        seedInventory(verma, products, 0.96, Map.of());

        CustomerAddress home = new CustomerAddress();
        home.setCustomer(customer);
        home.setLabel("Home");
        home.setAddressLine("102, Shree Residency, Scheme No. 54, Vijay Nagar");
        home.setCity("Indore");
        home.setState("Madhya Pradesh");
        home.setPostalCode("452010");
        home.setLatitude(22.7533);
        home.setLongitude(75.8937);
        home.setDefaultAddress(true);
        addressRepository.save(home);

        CustomerAddress office = new CustomerAddress();
        office.setCustomer(customer);
        office.setLabel("Office");
        office.setAddressLine("5th Floor, Crystal IT Park, Ring Road");
        office.setCity("Indore");
        office.setState("Madhya Pradesh");
        office.setPostalCode("452001");
        office.setLatitude(22.7244);
        office.setLongitude(75.8835);
        addressRepository.save(office);

        ensureCatalogExpansion();

        log.info("Demo data ready: {} categories, {} products, {} shops, {} inventory records",
                categoryRepository.count(), productRepository.count(), shopRepository.count(),
                inventoryRepository.count());
        log.info("Demo accounts: admin@puranabazaar.com / Admin@123 | customer@puranabazaar.com / Customer@123 | "
                + "sharma@puranabazaar.com / Owner@123 | delivery@puranabazaar.com / Delivery@123");
    }

    private void ensureDeliveryPartner() {
        String email = "delivery@puranabazaar.com";
        if (userRepository.existsByEmailIgnoreCase(email)) {
            return;
        }
        user("Ravi Kumar", email, "9000000003", "Delivery@123", Role.DELIVERY_PARTNER);
        log.info("Added demo delivery partner account: {} / Delivery@123", email);
    }

    private record CatalogSeed(String category, String name, String brand, String unit, String image, int price) {
    }

    /**
     * Adds a wider demo assortment without overwriting anything an admin or owner may have
     * changed. Safe to run on every boot: categories, products and shop listings are only
     * created when they are missing.
     */
    private void ensureCatalogExpansion() {
        Map<String, Category> categories = new LinkedHashMap<>();
        for (Category category : categoryRepository.findAllByOrderByDisplayOrderAscNameAsc()) {
            categories.putIfAbsent(category.getName().toLowerCase(Locale.ROOT), category);
        }
        ensureCategory(categories, "Frozen Foods", "Freezer staples, fries and ice creams",
                "https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=600&q=80", 10);
        ensureCategory(categories, "Baby Care", "Diapers, baby food and gentle care",
                "https://images.unsplash.com/photo-1519689680058-324335c77eba?w=600&q=80", 11);

        Map<String, Product> products = new HashMap<>();
        for (Product product : productRepository.findAll()) {
            products.putIfAbsent(product.getName().toLowerCase(Locale.ROOT), product);
        }

        List<Shop> shops = shopRepository.findApprovedAndActive();
        int newProducts = 0;
        int newListings = 0;
        for (CatalogSeed seed : catalogExpansion()) {
            Category category = categories.get(seed.category().toLowerCase(Locale.ROOT));
            if (category == null) {
                continue;
            }
            Product product = products.get(seed.name().toLowerCase(Locale.ROOT));
            if (product == null) {
                product = new Product();
                product.setName(seed.name());
                product.setBrand(seed.brand());
                product.setUnit(seed.unit());
                product.setImageUrl(seed.image());
                product.setDescription(seed.name() + " - quality checked and delivered from your local shop.");
                product.setCategory(category);
                product.setActive(true);
                productRepository.save(product);
                products.put(seed.name().toLowerCase(Locale.ROOT), product);
                newProducts++;
            }
            if (!product.isActive()) {
                continue;
            }
            for (Shop shop : shops) {
                if (inventoryRepository.findByShopAndProduct(shop.getId(), product.getId()).isPresent()) {
                    continue;
                }
                ShopInventory inventory = new ShopInventory();
                inventory.setShop(shop);
                inventory.setProduct(product);
                inventory.setPrice(BigDecimal.valueOf(seed.price())
                        .multiply(BigDecimal.valueOf(shopPriceMultiplier(shop)))
                        .setScale(0, RoundingMode.HALF_UP));
                inventory.setAvailableQuantity(8
                        + Math.floorMod((int) (product.getId() * 7 + shop.getId() * 11), 20));
                inventory.setActive(true);
                inventoryRepository.save(inventory);
                newListings++;
            }
        }
        if (newProducts > 0 || newListings > 0) {
            log.info("Catalog top-up complete: {} new products, {} new shop listings",
                    newProducts, newListings);
        }
    }

    private Category ensureCategory(Map<String, Category> categories, String name,
                                    String description, String image, int displayOrder) {
        String key = name.toLowerCase(Locale.ROOT);
        Category existing = categories.get(key);
        if (existing != null) {
            return existing;
        }
        Category category = new Category();
        category.setName(name);
        category.setDescription(description);
        category.setImageUrl(image);
        category.setDisplayOrder(displayOrder);
        category.setActive(true);
        categoryRepository.save(category);
        categories.put(key, category);
        log.info("Added demo category: {}", name);
        return category;
    }

    private double shopPriceMultiplier(Shop shop) {
        return switch (shop.getName()) {
            case "Sharma General Store" -> 1.05;
            case "Gupta Grocery Store" -> 0.98;
            case "City Mart" -> 1.03;
            case "Fresh Basket" -> 1.00;
            case "Verma Supermarket" -> 0.96;
            default -> 1.00;
        };
    }

    private List<CatalogSeed> catalogExpansion() {
        return List.of(
                new CatalogSeed("Vegetables", "Cucumber 500g", null, "500 g",
                        "https://images.unsplash.com/photo-1604977042946-1eecc30f269e?w=600&q=80", 30),
                new CatalogSeed("Vegetables", "Green Capsicum 500g", null, "500 g",
                        "https://images.unsplash.com/photo-1563565375-f3fdfdbefa83?w=600&q=80", 45),
                new CatalogSeed("Vegetables", "Fresh Coriander 100g", null, "100 g",
                        "https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=600&q=80", 15),
                new CatalogSeed("Fruits", "Pomegranate 1kg", null, "1 kg",
                        "https://images.unsplash.com/photo-1541344999736-83eca272f6fc?w=600&q=80", 140),
                new CatalogSeed("Fruits", "Sweet Lime 1kg", null, "1 kg",
                        "https://images.unsplash.com/photo-1590502593747-42a996133562?w=600&q=80", 80),
                new CatalogSeed("Dairy & Eggs", "Amul Masti Dahi 400g", "Amul", "400 g",
                        "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600&q=80", 45),
                new CatalogSeed("Dairy & Eggs", "Amul Cheese Slices 200g", "Amul", "200 g",
                        "https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=600&q=80", 140),
                new CatalogSeed("Dairy & Eggs", "Nestle A+ Toned Milk 1L", "Nestle", "1 L",
                        "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600&q=80", 75),
                new CatalogSeed("Bakery", "Multigrain Bread 400g", "Britannia", "400 g",
                        "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=80", 55),
                new CatalogSeed("Bakery", "Chocolate Muffins 2 pcs", null, "2 pcs",
                        "https://images.unsplash.com/photo-1607958996333-41aef7caefaa?w=600&q=80", 90),
                new CatalogSeed("Staples & Grains", "Tata Salt 1kg", "Tata", "1 kg",
                        "https://images.unsplash.com/photo-1518110925495-5fe2fda0442c?w=600&q=80", 28),
                new CatalogSeed("Staples & Grains", "Sugar 1kg", null, "1 kg",
                        "https://images.unsplash.com/photo-1581441363689-1f3c3c414635?w=600&q=80", 55),
                new CatalogSeed("Staples & Grains", "Chana Dal 1kg", "Tata Sampann", "1 kg",
                        "https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&q=80", 110),
                new CatalogSeed("Snacks & Munchies", "Bingo Mad Angles 66g", "Bingo", "66 g",
                        "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=600&q=80", 20),
                new CatalogSeed("Snacks & Munchies", "Sunfeast Dark Fantasy 300g", "Sunfeast", "300 g",
                        "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=600&q=80", 120),
                new CatalogSeed("Snacks & Munchies", "Roasted Almonds 200g", "Nutraj", "200 g",
                        "https://images.unsplash.com/photo-1508061253366-f7da158b6d46?w=600&q=80", 250),
                new CatalogSeed("Beverages", "Sprite 750ml", "Sprite", "750 ml",
                        "https://images.unsplash.com/photo-1554866585-cd94860890b7?w=600&q=80", 45),
                new CatalogSeed("Beverages", "Real Mixed Fruit Juice 1L", "Real", "1 L",
                        "https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=600&q=80", 130),
                new CatalogSeed("Beverages", "Lipton Green Tea 25 bags", "Lipton", "25 bags",
                        "https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&q=80", 180),
                new CatalogSeed("Personal Care", "Pond's Face Wash 100g", "Pond's", "100 g",
                        "https://images.unsplash.com/photo-1556228720-195a672e8a03?w=600&q=80", 190),
                new CatalogSeed("Personal Care", "Whisper Ultra 15 pads", "Whisper", "15 pads",
                        "https://images.unsplash.com/photo-1556228720-195a672e8a03?w=600&q=80", 175),
                new CatalogSeed("Household Essentials", "Comfort Fabric Conditioner 1L", "Comfort", "1 L",
                        "https://images.unsplash.com/photo-1585421514738-01798e348b17?w=600&q=80", 240),
                new CatalogSeed("Household Essentials", "Scotch-Brite Scrub Pad 3 pcs", "Scotch-Brite", "3 pcs",
                        "https://images.unsplash.com/photo-1585421514738-01798e348b17?w=600&q=80", 55),
                new CatalogSeed("Household Essentials", "Garbage Bags 30 pcs", null, "30 pcs",
                        "https://images.unsplash.com/photo-1585421514738-01798e348b17?w=600&q=80", 99),
                new CatalogSeed("Frozen Foods", "Safal Green Peas 500g", "Safal", "500 g",
                        "https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=600&q=80", 95),
                new CatalogSeed("Frozen Foods", "McCain French Fries 420g", "McCain", "420 g",
                        "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=600&q=80", 120),
                new CatalogSeed("Frozen Foods", "Amul Vanilla Ice Cream 1L", "Amul", "1 L",
                        "https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=600&q=80", 220),
                new CatalogSeed("Baby Care", "Pampers Diapers M 20 pcs", "Pampers", "20 pcs",
                        "https://images.unsplash.com/photo-1519689680058-324335c77eba?w=600&q=80", 399),
                new CatalogSeed("Baby Care", "Johnson's Baby Shampoo 200ml", "Johnson's", "200 ml",
                        "https://images.unsplash.com/photo-1556228720-195a672e8a03?w=600&q=80", 180),
                new CatalogSeed("Baby Care", "Cerelac Wheat Apple 300g", "Nestle", "300 g",
                        "https://images.unsplash.com/photo-1519689680058-324335c77eba?w=600&q=80", 275)
        );
    }

    private User user(String name, String email, String phone, String password, Role role) {
        User user = new User();
        user.setName(name);
        user.setEmail(email);
        user.setPhone(phone);
        user.setPassword(passwordEncoder.encode(password));
        user.setRole(role);
        user.setActive(true);
        return userRepository.save(user);
    }

    private Shop shop(String name, String email, String ownerName, String description,
                      String address, double lat, double lng, double radius, String category,
                      String image, String banner, String phone, ShopApprovalStatus status,
                      int etaMinutes) {
        User owner = user(ownerName, email, "90000000" + (10 + shopRepository.count()),
                "Owner@123", Role.SHOP_OWNER);
        Shop shop = new Shop();
        shop.setOwner(owner);
        shop.setName(name);
        shop.setDescription(description);
        shop.setAddress(address);
        shop.setLatitude(lat);
        shop.setLongitude(lng);
        shop.setOpeningTime(LocalTime.of(6, 0));
        shop.setClosingTime(LocalTime.of(23, 59));
        shop.setDeliveryRadius(radius);
        shop.setShopCategory(category);
        shop.setImageUrl(image);
        shop.setPhone(phone);
        shop.setEstimatedDeliveryMinutes(etaMinutes);
        shop.setApprovalStatus(status);
        shop.setOperationalStatus(ShopOperationalStatus.ACTIVE);
        if (status == ShopApprovalStatus.APPROVED) {
            shop.setApprovedAt(java.time.Instant.now());
        }
        return shopRepository.save(shop);
    }

    private Map<String, Category> seedCategories() {
        String[][] data = {
                {"Vegetables", "Fresh vegetables sourced daily", "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&q=80", "1"},
                {"Fruits", "Seasonal and everyday fruits", "https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=600&q=80", "2"},
                {"Dairy & Eggs", "Milk, butter, paneer and eggs", "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600&q=80", "3"},
                {"Bakery", "Breads, buns and baked treats", "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=80", "4"},
                {"Staples & Grains", "Atta, rice, dal and cooking oil", "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&q=80", "5"},
                {"Snacks & Munchies", "Chips, biscuits and namkeen", "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=600&q=80", "6"},
                {"Beverages", "Tea, coffee, juices and soft drinks", "https://images.unsplash.com/photo-1544145945-f90425340c7e?w=600&q=80", "7"},
                {"Personal Care", "Everyday personal care essentials", "https://images.unsplash.com/photo-1556228720-195a672e8a03?w=600&q=80", "8"},
                {"Household Essentials", "Cleaning and home care products", "https://images.unsplash.com/photo-1585421514738-01798e348b17?w=600&q=80", "9"}
        };
        Map<String, Category> map = new LinkedHashMap<>();
        for (String[] row : data) {
            Category category = new Category();
            category.setName(row[0]);
            category.setDescription(row[1]);
            category.setImageUrl(row[2]);
            category.setDisplayOrder(Integer.parseInt(row[3]));
            category.setActive(true);
            map.put(row[0], categoryRepository.save(category));
        }
        return map;
    }

    private Map<String, Product> seedProducts(Map<String, Category> categories) {
        Map<String, Product> map = new LinkedHashMap<>();
        addProduct(map, categories, "Vegetables", "Fresh Tomatoes 1kg", null, "1 kg",
                "https://images.unsplash.com/photo-1546094096-0df4bcaaa337?w=600&q=80", 40);
        addProduct(map, categories, "Vegetables", "Onions 1kg", null, "1 kg",
                "https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=600&q=80", 35);
        addProduct(map, categories, "Vegetables", "Potatoes 1kg", null, "1 kg",
                "https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=600&q=80", 30);
        addProduct(map, categories, "Vegetables", "Baby Spinach 250g", null, "250 g",
                "https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=600&q=80", 25);

        addProduct(map, categories, "Fruits", "Bananas 1kg", null, "1 kg",
                "https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=600&q=80", 50);
        addProduct(map, categories, "Fruits", "Shimla Apples 1kg", null, "1 kg",
                "https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?w=600&q=80", 120);
        addProduct(map, categories, "Fruits", "Nagpur Oranges 1kg", null, "1 kg",
                "https://images.unsplash.com/photo-1547514701-42782101795e?w=600&q=80", 90);

        addProduct(map, categories, "Dairy & Eggs", "Amul Taaza Toned Milk 1L", "Amul", "1 L",
                "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600&q=80", 62);
        addProduct(map, categories, "Dairy & Eggs", "Amul Butter 500g", "Amul", "500 g",
                "https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=600&q=80", 285);
        addProduct(map, categories, "Dairy & Eggs", "Fresh Paneer 200g", "Amul", "200 g",
                "https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=600&q=80", 95);
        addProduct(map, categories, "Dairy & Eggs", "Farm Eggs 12 pcs", null, "12 pcs",
                "https://images.unsplash.com/photo-1506976785307-8732e854ad03?w=600&q=80", 90);

        addProduct(map, categories, "Bakery", "Whole Wheat Bread 400g", "Britannia", "400 g",
                "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=80", 45);
        addProduct(map, categories, "Bakery", "White Sandwich Bread 400g", "Modern", "400 g",
                "https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=600&q=80", 40);
        addProduct(map, categories, "Bakery", "Butter Croissants 2 pcs", null, "2 pcs",
                "https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=600&q=80", 80);

        addProduct(map, categories, "Staples & Grains", "Basmati Rice 5kg", "India Gate", "5 kg",
                "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&q=80", 480);
        addProduct(map, categories, "Staples & Grains", "Aashirvaad Atta 5kg", "Aashirvaad", "5 kg",
                "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&q=80", 275);
        addProduct(map, categories, "Staples & Grains", "Toor Dal 1kg", "Tata Sampann", "1 kg",
                "https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&q=80", 165);
        addProduct(map, categories, "Staples & Grains", "Sunflower Oil 1L", "Fortune", "1 L",
                "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=600&q=80", 145);

        addProduct(map, categories, "Snacks & Munchies", "Lay's Classic Salted 90g", "Lay's", "90 g",
                "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=600&q=80", 30);
        addProduct(map, categories, "Snacks & Munchies", "Parle-G Biscuits 800g", "Parle", "800 g",
                "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=600&q=80", 90);
        addProduct(map, categories, "Snacks & Munchies", "Haldiram's Bhujia 400g", "Haldiram's", "400 g",
                "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&q=80", 110);

        addProduct(map, categories, "Beverages", "Tata Tea Premium 500g", "Tata Tea", "500 g",
                "https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=600&q=80", 260);
        addProduct(map, categories, "Beverages", "Nescafe Classic 100g", "Nescafe", "100 g",
                "https://images.unsplash.com/photo-1559525839-b184a4d698c7?w=600&q=80", 310);
        addProduct(map, categories, "Beverages", "Coca-Cola 1.25L", "Coca-Cola", "1.25 L",
                "https://images.unsplash.com/photo-1554866585-cd94860890b7?w=600&q=80", 70);
        addProduct(map, categories, "Beverages", "Tropicana Orange Juice 1L", "Tropicana", "1 L",
                "https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=600&q=80", 125);

        addProduct(map, categories, "Personal Care", "Colgate Strong Teeth 200g", "Colgate", "200 g",
                "https://images.unsplash.com/photo-1556228578-8c89e6adf883?w=600&q=80", 115);
        addProduct(map, categories, "Personal Care", "Dove Soap 3 x 100g", "Dove", "300 g",
                "https://images.unsplash.com/photo-1600857544200-b2f666a9a2ec?w=600&q=80", 210);
        addProduct(map, categories, "Personal Care", "Head & Shoulders Shampoo 340ml", "Head & Shoulders", "340 ml",
                "https://images.unsplash.com/photo-1571781926291-c477ebfd024b?w=600&q=80", 340);

        addProduct(map, categories, "Household Essentials", "Surf Excel Matic 1kg", "Surf Excel", "1 kg",
                "https://images.unsplash.com/photo-1585421514738-01798e348b17?w=600&q=80", 220);
        addProduct(map, categories, "Household Essentials", "Vim Dishwash Bar 3 pcs", "Vim", "3 pcs",
                "https://images.unsplash.com/photo-1585421514738-01798e348b17?w=600&q=80", 45);
        addProduct(map, categories, "Household Essentials", "Harpic Toilet Cleaner 1L", "Harpic", "1 L",
                "https://images.unsplash.com/photo-1585421514738-01798e348b17?w=600&q=80", 185);

        return map;
    }

    private void addProduct(Map<String, Product> map, Map<String, Category> categories, String category,
                            String name, String brand, String unit, String image, int basePrice) {
        Product product = new Product();
        product.setName(name);
        product.setBrand(brand);
        product.setUnit(unit);
        product.setImageUrl(image);
        product.setDescription(name + " - quality checked and delivered from your local shop.");
        product.setCategory(categories.get(category));
        product.setActive(true);
        map.put(name, productRepository.save(product));
        product.setDescription(name + " - quality checked and delivered from your local shop. Base price ₹"
                + basePrice + ".");
        productRepository.save(product);
    }

    private void seedInventory(Shop shop, Map<String, Product> products, double multiplier,
                               Map<String, Integer> overrides) {
        int index = 0;
        for (Product product : products.values()) {
            Integer override = overrides.get(product.getName());
            if (override != null && override == 0) {
                index++;
                continue; // shop does not carry this product
            }
            ShopInventory inventory = new ShopInventory();
            inventory.setShop(shop);
            inventory.setProduct(product);
            BigDecimal basePrice = basePriceFor(product.getName());
            inventory.setPrice(basePrice.multiply(BigDecimal.valueOf(multiplier))
                    .setScale(0, RoundingMode.HALF_UP));
            int quantity = override != null ? override : 6 + ((index * 7 + (int) (shop.getId() * 3)) % 26);
            inventory.setAvailableQuantity(quantity);
            inventory.setActive(true);
            inventoryRepository.save(inventory);
            index++;
        }
    }

    private BigDecimal basePriceFor(String name) {
        return switch (name) {
            case "Fresh Tomatoes 1kg", "Onions 1kg", "Potatoes 1kg" -> BigDecimal.valueOf(45);
            case "Baby Spinach 250g" -> BigDecimal.valueOf(35);
            case "Bananas 1kg" -> BigDecimal.valueOf(60);
            case "Shimla Apples 1kg" -> BigDecimal.valueOf(160);
            case "Nagpur Oranges 1kg" -> BigDecimal.valueOf(110);
            case "Amul Taaza Toned Milk 1L" -> BigDecimal.valueOf(62);
            case "Amul Butter 500g" -> BigDecimal.valueOf(285);
            case "Fresh Paneer 200g" -> BigDecimal.valueOf(95);
            case "Farm Eggs 12 pcs" -> BigDecimal.valueOf(90);
            case "Whole Wheat Bread 400g" -> BigDecimal.valueOf(45);
            case "White Sandwich Bread 400g" -> BigDecimal.valueOf(40);
            case "Butter Croissants 2 pcs" -> BigDecimal.valueOf(80);
            case "Basmati Rice 5kg" -> BigDecimal.valueOf(480);
            case "Aashirvaad Atta 5kg" -> BigDecimal.valueOf(275);
            case "Toor Dal 1kg" -> BigDecimal.valueOf(165);
            case "Sunflower Oil 1L" -> BigDecimal.valueOf(145);
            case "Lay's Classic Salted 90g" -> BigDecimal.valueOf(30);
            case "Parle-G Biscuits 800g" -> BigDecimal.valueOf(90);
            case "Haldiram's Bhujia 400g" -> BigDecimal.valueOf(110);
            case "Tata Tea Premium 500g" -> BigDecimal.valueOf(260);
            case "Nescafe Classic 100g" -> BigDecimal.valueOf(310);
            case "Coca-Cola 1.25L" -> BigDecimal.valueOf(70);
            case "Tropicana Orange Juice 1L" -> BigDecimal.valueOf(125);
            case "Colgate Strong Teeth 200g" -> BigDecimal.valueOf(115);
            case "Dove Soap 3 x 100g" -> BigDecimal.valueOf(210);
            case "Head & Shoulders Shampoo 340ml" -> BigDecimal.valueOf(340);
            case "Surf Excel Matic 1kg" -> BigDecimal.valueOf(220);
            case "Vim Dishwash Bar 3 pcs" -> BigDecimal.valueOf(45);
            case "Harpic Toilet Cleaner 1L" -> BigDecimal.valueOf(185);
            default -> BigDecimal.valueOf(100);
        };
    }
}
