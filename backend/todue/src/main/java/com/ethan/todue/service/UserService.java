package com.ethan.todue.service;

import com.ethan.todue.model.User;
import com.ethan.todue.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneId;

@Service
public class UserService {

    @Autowired
    private UserRepository userRepository;

    public User getCurrentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        String email = authentication.getName();
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));
    }

    @Transactional
    public void updateTimezone(String timezone) {
        User user = getCurrentUser();
        user.setTimezone(timezone);
        userRepository.save(user);
    }

    public String getUserTimezone() {
        return getCurrentUser().getTimezone();
    }

    public LocalDate getCurrentDateForUser() {
        String timezone = getUserTimezone();
        return LocalDate.now(ZoneId.of(timezone));
    }
}
