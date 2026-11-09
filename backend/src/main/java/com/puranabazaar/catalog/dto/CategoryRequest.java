package com.puranabazaar.catalog.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record CategoryRequest(
        @NotBlank @Size(max = 100) String name,
        @Size(max = 500) String description,
        @Size(max = 500) String imageUrl,
        Boolean active,
        Integer displayOrder
) {
}
