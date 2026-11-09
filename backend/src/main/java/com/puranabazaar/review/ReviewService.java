package com.puranabazaar.review;

import com.puranabazaar.common.ApiException;
import com.puranabazaar.order.OrderRepository;
import com.puranabazaar.order.OrderStatus;
import com.puranabazaar.review.dto.ReviewRequest;
import com.puranabazaar.review.dto.ReviewResponse;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.shop.Shop;
import com.puranabazaar.shop.ShopApprovalStatus;
import com.puranabazaar.shop.ShopRepository;
import com.puranabazaar.user.User;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final ShopRepository shopRepository;
    private final OrderRepository orderRepository;

    public ReviewService(ReviewRepository reviewRepository, ShopRepository shopRepository,
                         OrderRepository orderRepository) {
        this.reviewRepository = reviewRepository;
        this.shopRepository = shopRepository;
        this.orderRepository = orderRepository;
    }

    @Transactional(readOnly = true)
    public List<ReviewResponse> list(Long shopId) {
        return reviewRepository.findByShopIdOrderByCreatedAtDesc(shopId).stream()
                .map(this::toResponse).toList();
    }

    @Transactional
    public ReviewResponse submit(Long shopId, ReviewRequest request) {
        User customer = CurrentUser.require();
        Shop shop = shopRepository.findById(shopId)
                .filter(s -> s.getApprovalStatus() == ShopApprovalStatus.APPROVED)
                .orElseThrow(() -> ApiException.notFound("SHOP_NOT_FOUND", "Shop not found."));
        if (!orderRepository.existsByCustomerIdAndShopIdAndOrderStatus(customer.getId(), shopId, OrderStatus.DELIVERED)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "REVIEW_NOT_ALLOWED",
                    "You can review a shop after receiving a delivered order from it.");
        }
        Review review = reviewRepository.findByCustomerIdAndShopId(customer.getId(), shopId)
                .orElseGet(() -> {
                    Review created = new Review();
                    created.setCustomer(customer);
                    created.setShop(shop);
                    return created;
                });
        review.setRating(request.rating());
        review.setComment(request.comment());
        return toResponse(reviewRepository.save(review));
    }

    private ReviewResponse toResponse(Review review) {
        return new ReviewResponse(review.getId(), review.getCustomer().getId(), review.getCustomer().getName(),
                review.getRating(), review.getComment(), review.getCreatedAt());
    }
}
