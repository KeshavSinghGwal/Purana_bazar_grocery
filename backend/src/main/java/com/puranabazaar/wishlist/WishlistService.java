package com.puranabazaar.wishlist;

import com.puranabazaar.catalog.CatalogMapper;
import com.puranabazaar.catalog.CatalogService;
import com.puranabazaar.catalog.Product;
import com.puranabazaar.catalog.ProductRepository;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.user.User;
import com.puranabazaar.wishlist.dto.WishlistItemResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class WishlistService {

    private final WishlistRepository wishlistRepository;
    private final ProductRepository productRepository;
    private final CatalogService catalogService;

    public WishlistService(WishlistRepository wishlistRepository, ProductRepository productRepository,
                           CatalogService catalogService) {
        this.wishlistRepository = wishlistRepository;
        this.productRepository = productRepository;
        this.catalogService = catalogService;
    }

    @Transactional(readOnly = true)
    public List<WishlistItemResponse> list() {
        var availability = catalogService.availability();
        return wishlistRepository.findByCustomerIdOrderByCreatedAtDesc(CurrentUser.id()).stream()
                .map(item -> new WishlistItemResponse(item.getId(),
                        CatalogMapper.toProduct(item.getProduct(), availability), item.getCreatedAt()))
                .toList();
    }

    @Transactional
    public WishlistItemResponse add(Long productId) {
        User customer = CurrentUser.require();
        Product product = productRepository.findByIdAndActiveTrue(productId)
                .orElseThrow(() -> ApiException.notFound("PRODUCT_NOT_FOUND", "Product not found."));
        WishlistItem item = wishlistRepository.findByCustomerIdAndProductId(customer.getId(), productId)
                .orElseGet(() -> {
                    WishlistItem created = new WishlistItem();
                    created.setCustomer(customer);
                    created.setProduct(product);
                    return wishlistRepository.save(created);
                });
        return new WishlistItemResponse(item.getId(),
                CatalogMapper.toProduct(item.getProduct(), catalogService.availability()), item.getCreatedAt());
    }

    @Transactional
    public void remove(Long productId) {
        Long customerId = CurrentUser.id();
        if (!wishlistRepository.existsByCustomerIdAndProductId(customerId, productId)) {
            throw ApiException.notFound("WISHLIST_ITEM_NOT_FOUND", "Wishlist item not found.");
        }
        wishlistRepository.deleteByCustomerIdAndProductId(customerId, productId);
    }
}
