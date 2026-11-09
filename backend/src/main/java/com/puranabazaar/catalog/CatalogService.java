package com.puranabazaar.catalog;

import com.puranabazaar.catalog.dto.*;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.common.PageResponse;
import com.puranabazaar.inventory.ShopInventoryRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class CatalogService {

    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final ShopInventoryRepository inventoryRepository;

    public CatalogService(CategoryRepository categoryRepository, ProductRepository productRepository,
                          ShopInventoryRepository inventoryRepository) {
        this.categoryRepository = categoryRepository;
        this.productRepository = productRepository;
        this.inventoryRepository = inventoryRepository;
    }

    public record Availability(BigDecimal bestPrice, int availableShops, int totalStock) {
    }

    @Transactional(readOnly = true)
    public List<CategoryResponse> listCategories(boolean includeInactive) {
        List<Category> categories = includeInactive
                ? categoryRepository.findAllByOrderByDisplayOrderAscNameAsc()
                : categoryRepository.findAllByActiveTrueOrderByDisplayOrderAscNameAsc();
        return categories.stream().map(CatalogMapper::toCategory).toList();
    }

    @Transactional(readOnly = true)
    public List<ProductResponse> productsByCategory(Long categoryId) {
        categoryRepository.findById(categoryId)
                .orElseThrow(() -> ApiException.notFound("CATEGORY_NOT_FOUND", "Category not found."));
        Map<Long, Availability> availability = availability();
        return productRepository.findActiveByCategory(categoryId).stream()
                .map(product -> CatalogMapper.toProduct(product, availability))
                .toList();
    }

    @Transactional(readOnly = true)
    public PageResponse<ProductResponse> searchProducts(String query, Long categoryId,
                                                        int page, int size, BigDecimal maxPrice,
                                                        boolean availableOnly) {
        String term = normalize(query);
        Pageable pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 60),
                Sort.by(Sort.Direction.ASC, "name"));
        Page<Product> result = productRepository.search(term, categoryId, pageable);
        Map<Long, Availability> availability = availability();
        List<ProductResponse> content = result.getContent().stream()
                .map(product -> CatalogMapper.toProduct(product, availability))
                .filter(item -> !availableOnly || item.availableShops() > 0)
                .filter(item -> maxPrice == null || (item.bestPrice() != null && item.bestPrice().compareTo(maxPrice) <= 0))
                .toList();
        return new PageResponse<>(content, result.getNumber(), result.getSize(),
                result.getTotalElements(), result.getTotalPages(), result.isLast());
    }

    @Transactional(readOnly = true)
    public ProductResponse getProduct(Long id) {
        Product product = productRepository.findByIdAndActiveTrue(id)
                .orElseThrow(() -> ApiException.notFound("PRODUCT_NOT_FOUND", "Product not found."));
        return CatalogMapper.toProduct(product, availability());
    }

    @Transactional(readOnly = true)
    public PageResponse<ProductResponse> adminProducts(String query, Long categoryId, int page, int size) {
        Pageable pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100),
                Sort.by(Sort.Direction.ASC, "name"));
        Page<Product> result = productRepository.adminSearch(normalize(query), categoryId, pageable);
        Map<Long, Availability> availability = availability();
        return new PageResponse<>(result.getContent().stream()
                .map(product -> CatalogMapper.toProduct(product, availability)).toList(),
                result.getNumber(), result.getSize(), result.getTotalElements(),
                result.getTotalPages(), result.isLast());
    }

    @Transactional(readOnly = true)
    public Map<Long, Availability> availability() {
        Map<Long, Availability> map = new HashMap<>();
        for (Object[] row : inventoryRepository.aggregateAvailability()) {
            Long productId = ((Number) row[0]).longValue();
            BigDecimal price = (BigDecimal) row[1];
            int stock = ((Number) row[2]).intValue();
            int shops = ((Number) row[3]).intValue();
            map.put(productId, new Availability(price, shops, stock));
        }
        return map;
    }

    public ProductResponse mapProduct(Product product, Map<Long, Availability> availability) {
        return CatalogMapper.toProduct(product, availability);
    }

    // ------------------------- Admin: categories -------------------------

    @Transactional
    public CategoryResponse createCategory(CategoryRequest request) {
        if (categoryRepository.existsByNameIgnoreCase(request.name().trim())) {
            throw ApiException.conflict("CATEGORY_EXISTS", "A category with this name already exists.");
        }
        Category category = new Category();
        applyCategory(category, request);
        return CatalogMapper.toCategory(categoryRepository.save(category));
    }

    @Transactional
    public CategoryResponse updateCategory(Long id, CategoryRequest request) {
        Category category = categoryRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("CATEGORY_NOT_FOUND", "Category not found."));
        if (!category.getName().equalsIgnoreCase(request.name().trim())
                && categoryRepository.existsByNameIgnoreCase(request.name().trim())) {
            throw ApiException.conflict("CATEGORY_EXISTS", "A category with this name already exists.");
        }
        applyCategory(category, request);
        return CatalogMapper.toCategory(categoryRepository.save(category));
    }

    @Transactional
    public void deactivateCategory(Long id) {
        Category category = categoryRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("CATEGORY_NOT_FOUND", "Category not found."));
        category.setActive(false);
        categoryRepository.save(category);
    }

    // ------------------------- Admin: products -------------------------

    @Transactional
    public ProductResponse createProduct(ProductRequest request) {
        Category category = categoryRepository.findById(request.categoryId())
                .orElseThrow(() -> ApiException.notFound("CATEGORY_NOT_FOUND", "Category not found."));
        Product product = new Product();
        applyProduct(product, request, category);
        productRepository.save(product);
        return CatalogMapper.toProduct(product, Map.of());
    }

    @Transactional
    public ProductResponse updateProduct(Long id, ProductRequest request) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("PRODUCT_NOT_FOUND", "Product not found."));
        Category category = categoryRepository.findById(request.categoryId())
                .orElseThrow(() -> ApiException.notFound("CATEGORY_NOT_FOUND", "Category not found."));
        applyProduct(product, request, category);
        productRepository.save(product);
        return CatalogMapper.toProduct(product, availability());
    }

    @Transactional
    public void deactivateProduct(Long id) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> ApiException.notFound("PRODUCT_NOT_FOUND", "Product not found."));
        product.setActive(false);
        productRepository.save(product);
    }

    private void applyCategory(Category category, CategoryRequest request) {
        category.setName(request.name().trim());
        category.setDescription(request.description());
        category.setImageUrl(request.imageUrl());
        category.setActive(request.active() == null || request.active());
        category.setDisplayOrder(request.displayOrder() == null ? 0 : request.displayOrder());
    }

    private void applyProduct(Product product, ProductRequest request, Category category) {
        product.setName(request.name().trim());
        product.setDescription(request.description());
        product.setBrand(request.brand());
        product.setCategory(category);
        product.setImageUrl(request.imageUrl());
        product.setUnit(request.unit().trim());
        product.setActive(request.active() == null || request.active());
    }

    private String normalize(String query) {
        return query == null || query.isBlank() ? "" : query.trim();
    }
}
