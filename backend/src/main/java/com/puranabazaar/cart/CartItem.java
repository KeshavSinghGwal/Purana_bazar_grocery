package com.puranabazaar.cart;

import com.puranabazaar.catalog.Product;
import com.puranabazaar.inventory.ShopInventory;
import jakarta.persistence.*;

@Entity
@Table(name = "cart_items", indexes = {
        @Index(name = "idx_cart_items_cart", columnList = "cart_id")
}, uniqueConstraints = {
        @UniqueConstraint(name = "uk_cart_items_product", columnNames = {"cart_id", "product_id"}),
        @UniqueConstraint(name = "uk_cart_items_inventory", columnNames = {"cart_id", "shop_inventory_id"})
})
public class CartItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "cart_id", nullable = false)
    private Cart cart;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id")
    private Product product;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shop_inventory_id")
    private ShopInventory shopInventory;

    @Column(nullable = false)
    private int quantity;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Cart getCart() { return cart; }
    public void setCart(Cart cart) { this.cart = cart; }
    public Product getProduct() { return product; }
    public void setProduct(Product product) { this.product = product; }
    public ShopInventory getShopInventory() { return shopInventory; }
    public void setShopInventory(ShopInventory shopInventory) { this.shopInventory = shopInventory; }
    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }
}
