package com.puranabazaar.catalog.dto;

public record CategoryResponse(
        Long id,
        String name,
        String description,
        String imageUrl,
        boolean active,
        int displayOrder
) {
}
