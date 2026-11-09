package com.puranabazaar.address;

import com.puranabazaar.address.dto.AddressRequest;
import com.puranabazaar.address.dto.AddressResponse;
import com.puranabazaar.common.ApiException;
import com.puranabazaar.security.CurrentUser;
import com.puranabazaar.user.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class AddressService {

    private final CustomerAddressRepository addressRepository;

    public AddressService(CustomerAddressRepository addressRepository) {
        this.addressRepository = addressRepository;
    }

    @Transactional(readOnly = true)
    public List<AddressResponse> list() {
        Long customerId = CurrentUser.id();
        return addressRepository.findByCustomerIdOrderByDefaultAddressDescCreatedAtDesc(customerId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional
    public AddressResponse create(AddressRequest request) {
        User customer = CurrentUser.require();
        long count = addressRepository.countByCustomerId(customer.getId());
        boolean makeDefault = Boolean.TRUE.equals(request.isDefault()) || count == 0;
        if (makeDefault) {
            addressRepository.clearDefaultForCustomer(customer.getId());
        }
        CustomerAddress address = new CustomerAddress();
        address.setCustomer(customer);
        apply(address, request);
        address.setDefaultAddress(makeDefault);
        return toResponse(addressRepository.save(address));
    }

    @Transactional
    public AddressResponse update(Long id, AddressRequest request) {
        User customer = CurrentUser.require();
        CustomerAddress address = addressRepository.findByIdAndCustomerId(id, customer.getId())
                .orElseThrow(() -> ApiException.notFound("ADDRESS_NOT_FOUND", "Delivery address not found."));
        boolean makeDefault = Boolean.TRUE.equals(request.isDefault());
        if (makeDefault) {
            addressRepository.clearDefaultForCustomer(customer.getId());
        }
        apply(address, request);
        if (makeDefault) {
            address.setDefaultAddress(true);
        }
        return toResponse(addressRepository.save(address));
    }

    @Transactional
    public void delete(Long id) {
        User customer = CurrentUser.require();
        CustomerAddress address = addressRepository.findByIdAndCustomerId(id, customer.getId())
                .orElseThrow(() -> ApiException.notFound("ADDRESS_NOT_FOUND", "Delivery address not found."));
        boolean wasDefault = address.isDefaultAddress();
        addressRepository.delete(address);
        if (wasDefault) {
            addressRepository.findByCustomerIdOrderByDefaultAddressDescCreatedAtDesc(customer.getId())
                    .stream().findFirst().ifPresent(next -> {
                        next.setDefaultAddress(true);
                        addressRepository.save(next);
                    });
        }
    }

    @Transactional
    public AddressResponse setDefault(Long id) {
        User customer = CurrentUser.require();
        CustomerAddress address = addressRepository.findByIdAndCustomerId(id, customer.getId())
                .orElseThrow(() -> ApiException.notFound("ADDRESS_NOT_FOUND", "Delivery address not found."));
        addressRepository.clearDefaultForCustomer(customer.getId());
        address.setDefaultAddress(true);
        return toResponse(addressRepository.save(address));
    }

    private void apply(CustomerAddress address, AddressRequest request) {
        if (request.label() != null && !request.label().isBlank()) {
            address.setLabel(request.label().trim());
        }
        address.setAddressLine(request.addressLine().trim());
        address.setCity(request.city().trim());
        address.setState(request.state().trim());
        address.setPostalCode(request.postalCode().trim());
        address.setLatitude(request.latitude());
        address.setLongitude(request.longitude());
    }

    public AddressResponse toResponse(CustomerAddress address) {
        return new AddressResponse(address.getId(), address.getLabel(), address.getAddressLine(),
                address.getCity(), address.getState(), address.getPostalCode(), address.getLatitude(),
                address.getLongitude(), address.isDefaultAddress(), address.asText(), address.getCreatedAt());
    }
}
