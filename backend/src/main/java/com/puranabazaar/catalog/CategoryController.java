package com.puranabazaar.catalog;

import com.puranabazaar.catalog.dto.CategoryResponse;
import com.puranabazaar.catalog.dto.ProductResponse;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/categories")
public class CategoryController {

    private final CatalogService catalogService;

    public CategoryController(CatalogService catalogService) {
        this.catalogService = catalogService;
    }

    @GetMapping
    public List<CategoryResponse> list() {
        return catalogService.listCategories(false);
    }

    @GetMapping("/{id}/products")
    public List<ProductResponse> products(@PathVariable Long id) {
        return catalogService.productsByCategory(id);
    }
}
