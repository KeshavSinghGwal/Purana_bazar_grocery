package com.puranabazaar.customer;

import com.puranabazaar.auth.AuthService;
import com.puranabazaar.auth.dto.UserResponse;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/customers")
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerController {

    private final AuthService authService;

    public CustomerController(AuthService authService) {
        this.authService = authService;
    }

    public record UpdateProfileRequest(
            @Size(min = 2, max = 120) String name,
            @Pattern(regexp = "^$|^[0-9+\\- ]{8,20}$", message = "Enter a valid phone number") String phone
    ) {
    }

    @GetMapping("/profile")
    public UserResponse profile() {
        return authService.toUser(com.puranabazaar.security.CurrentUser.require());
    }

    @PutMapping("/profile")
    public UserResponse update(@RequestBody UpdateProfileRequest request) {
        return authService.updateProfile(request.name(), request.phone());
    }
}
