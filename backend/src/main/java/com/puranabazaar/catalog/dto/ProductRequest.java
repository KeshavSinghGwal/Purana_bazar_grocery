package com.puranabazaar.catalog.dto;

import jakarta.validation.constraints.*;

public record ProductRequest(
        @NotBlank @Size(max = 150) String name,
        @Size(max = 2000) String description,
        @Size(max = 100) String brand,
        @NotNull Long categoryId,
        @Size(max = 500) String imageUrl,
        @NotBlank @Size(max = 40) String unit,
        Boolean active
) {
}
