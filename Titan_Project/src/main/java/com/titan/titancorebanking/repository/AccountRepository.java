package com.titan.titancorebanking.repository;

import com.titan.titancorebanking.model.Account;
import com.titan.titancorebanking.model.User; // Ensure User model is imported
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;

import java.util.List;
import java.util.Optional;

public interface AccountRepository extends JpaRepository<Account, Long> {

    // ✅ Find accounts by User (Supports 'getMyAccounts')
    List<Account> findByUserUsername(String username);

    // ✅ Find single account by Account Number
    Optional<Account> findByAccountNumber(String accountNumber);

    // ✅ FIX: Add this method for 'createAccount' retry logic
    boolean existsByAccountNumber(String accountNumber);

    // ✅ Count accounts for Limit Check
    long countByUser(User user);

    // ✅ Pessimistic Lock for safe transfers (Prevent Double Spend)
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT a FROM Account a WHERE a.accountNumber = :accountNumber")
    Optional<Account> findByAccountNumberForUpdate(@Param("accountNumber") String accountNumber);
}