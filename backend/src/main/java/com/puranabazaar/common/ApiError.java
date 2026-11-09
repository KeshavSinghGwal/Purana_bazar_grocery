package com.puranabazaar.common;

import java.time.Instant;
import java.util.Map;

public record ApiError(
        Instant timestamp,
        int status,
        String code,
        String message,
        String path,
        Object details,
        Map<String, String> fieldErrors
) {
}
