package com.ethan.todue.repository;

import com.ethan.todue.model.EmailVerification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface EmailVerificationRepository extends JpaRepository<EmailVerification, Long> {

    Optional<EmailVerification> findByToken(String token);

    void deleteByUserId(Long userId);

    boolean existsByUserId(Long userId);
}
