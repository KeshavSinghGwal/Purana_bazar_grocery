package com.puranabazaar.security;

import com.puranabazaar.common.ApiException;
import com.puranabazaar.user.User;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

public final class CurrentUser {

    private CurrentUser() {
    }

    public static User require() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof User user)) {
            throw ApiException.unauthorized("Please sign in to continue.");
        }
        return user;
    }

    public static Long id() {
        return require().getId();
    }
}
