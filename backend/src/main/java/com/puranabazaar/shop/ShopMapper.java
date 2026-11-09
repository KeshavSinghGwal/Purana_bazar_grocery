package com.puranabazaar.shop;

import com.puranabazaar.common.GeoUtils;
import com.puranabazaar.review.ReviewRepository;
import com.puranabazaar.shop.dto.ShopResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.LocalTime;
import java.time.ZoneId;

@Component
public class ShopMapper {

    private final ReviewRepository reviewRepository;
    private final ZoneId zoneId;

    public ShopMapper(ReviewRepository reviewRepository,
                      @Value("${app.timezone:Asia/Kolkata}") String timezone) {
        this.reviewRepository = reviewRepository;
        this.zoneId = ZoneId.of(timezone);
    }

    public ShopResponse toResponse(Shop shop, Double customerLatitude, Double customerLongitude) {
        Double distance = null;
        boolean deliverable = true;
        if (customerLatitude != null && customerLongitude != null) {
            distance = GeoUtils.round2(GeoUtils.distanceKm(
                    customerLatitude, customerLongitude, shop.getLatitude(), shop.getLongitude()));
            deliverable = distance <= shop.getDeliveryRadius();
        }
        Double rating = reviewRepository.averageRating(shop.getId());
        if (rating != null) {
            rating = Math.round(rating * 10.0) / 10.0;
        }
        return new ShopResponse(
                shop.getId(),
                shop.getOwner().getId(),
                shop.getOwner().getName(),
                shop.getName(),
                shop.getDescription(),
                shop.getAddress(),
                shop.getLatitude(),
                shop.getLongitude(),
                shop.getOpeningTime(),
                shop.getClosingTime(),
                shop.getDeliveryRadius(),
                shop.isDeliveryAvailable(),
                shop.getEstimatedDeliveryMinutes(),
                shop.getApprovalStatus().name(),
                shop.getOperationalStatus().name(),
                shop.getShopCategory(),
                shop.getImageUrl(),
                shop.getPhone(),
                distance,
                deliverable,
                shop.isOpenAt(LocalTime.now(zoneId)),
                rating,
                reviewRepository.countByShopId(shop.getId()),
                shop.getRejectionReason(),
                shop.getCreatedAt()
        );
    }
}
