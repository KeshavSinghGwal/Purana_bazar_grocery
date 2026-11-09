package com.puranabazaar.cart;

import com.puranabazaar.shop.Shop;
import com.puranabazaar.user.User;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "carts", uniqueConstraints = {
        @UniqueConstraint(name = "uk_carts_customer", columnNames = "customer_id")
})
public class Cart {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private ShoppingMode shoppingMode;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "selected_shop_id")
    private Shop selectedShop;

    @OneToMany(mappedBy = "cart", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("id ASC")
    private List<CartItem> items = new ArrayList<>();

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    @PreUpdate
    void touch() {
        this.updatedAt = Instant.now();
    }

    public void addItem(CartItem item) {
        items.add(item);
        item.setCart(this);
    }

    public void clearItems() {
        items.clear();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public User getCustomer() { return customer; }
    public void setCustomer(User customer) { this.customer = customer; }
    public ShoppingMode getShoppingMode() { return shoppingMode; }
    public void setShoppingMode(ShoppingMode shoppingMode) { this.shoppingMode = shoppingMode; }
    public Shop getSelectedShop() { return selectedShop; }
    public void setSelectedShop(Shop selectedShop) { this.selectedShop = selectedShop; }
    public List<CartItem> getItems() { return items; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
