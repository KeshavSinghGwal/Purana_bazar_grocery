package com.puranabazaar.shop;

import com.puranabazaar.user.User;
import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalTime;

@Entity
@Table(name = "shops", indexes = {
        @Index(name = "idx_shops_status", columnList = "approvalStatus"),
        @Index(name = "idx_shops_location", columnList = "latitude,longitude")
}, uniqueConstraints = {
        @UniqueConstraint(name = "uk_shops_owner", columnNames = "owner_id")
})
public class Shop {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "owner_id", nullable = false)
    private User owner;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(columnDefinition = "text")
    private String description;

    @Column(nullable = false, length = 400)
    private String address;

    @Column(nullable = false)
    private double latitude;

    @Column(nullable = false)
    private double longitude;

    @Column(nullable = false)
    private LocalTime openingTime = LocalTime.of(7, 0);

    @Column(nullable = false)
    private LocalTime closingTime = LocalTime.of(23, 0);

    /** Service radius in kilometres. */
    @Column(nullable = false)
    private double deliveryRadius = 5.0;

    @Column(nullable = false)
    private boolean deliveryAvailable = true;

    @Column(nullable = false)
    private int estimatedDeliveryMinutes = 30;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private ShopApprovalStatus approvalStatus = ShopApprovalStatus.PENDING_APPROVAL;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private ShopOperationalStatus operationalStatus = ShopOperationalStatus.ACTIVE;

    @Column(length = 80)
    private String shopCategory;

    @Column(length = 500)
    private String imageUrl;

    @Column(length = 20)
    private String phone;

    @Column(length = 500)
    private String rejectionReason;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    private Instant approvedAt;

    public boolean isOpenAt(LocalTime time) {
        if (openingTime.equals(closingTime)) {
            return true;
        }
        if (openingTime.isBefore(closingTime)) {
            return !time.isBefore(openingTime) && time.isBefore(closingTime);
        }
        // Overnight opening window, e.g. 18:00 - 02:00
        return !time.isBefore(openingTime) || time.isBefore(closingTime);
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public User getOwner() { return owner; }
    public void setOwner(User owner) { this.owner = owner; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }
    public double getLatitude() { return latitude; }
    public void setLatitude(double latitude) { this.latitude = latitude; }
    public double getLongitude() { return longitude; }
    public void setLongitude(double longitude) { this.longitude = longitude; }
    public LocalTime getOpeningTime() { return openingTime; }
    public void setOpeningTime(LocalTime openingTime) { this.openingTime = openingTime; }
    public LocalTime getClosingTime() { return closingTime; }
    public void setClosingTime(LocalTime closingTime) { this.closingTime = closingTime; }
    public double getDeliveryRadius() { return deliveryRadius; }
    public void setDeliveryRadius(double deliveryRadius) { this.deliveryRadius = deliveryRadius; }
    public boolean isDeliveryAvailable() { return deliveryAvailable; }
    public void setDeliveryAvailable(boolean deliveryAvailable) { this.deliveryAvailable = deliveryAvailable; }
    public int getEstimatedDeliveryMinutes() { return estimatedDeliveryMinutes; }
    public void setEstimatedDeliveryMinutes(int estimatedDeliveryMinutes) { this.estimatedDeliveryMinutes = estimatedDeliveryMinutes; }
    public ShopApprovalStatus getApprovalStatus() { return approvalStatus; }
    public void setApprovalStatus(ShopApprovalStatus approvalStatus) { this.approvalStatus = approvalStatus; }
    public ShopOperationalStatus getOperationalStatus() { return operationalStatus; }
    public void setOperationalStatus(ShopOperationalStatus operationalStatus) { this.operationalStatus = operationalStatus; }
    public String getShopCategory() { return shopCategory; }
    public void setShopCategory(String shopCategory) { this.shopCategory = shopCategory; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public String getRejectionReason() { return rejectionReason; }
    public void setRejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Instant getApprovedAt() { return approvedAt; }
    public void setApprovedAt(Instant approvedAt) { this.approvedAt = approvedAt; }
}
