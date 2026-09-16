package com.titan.titancorebanking.repository;

import com.titan.titancorebanking.model.Transaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    // ✅ FIX: Custom JPQL Query
    // រកមើល Transaction ណាដែល User ជាម្ចាស់គណនីផ្ញើ (fromAccount) ឬ ជាម្ចាស់គណនីទទួល (toAccount)
    @Query("SELECT t FROM Transaction t WHERE " +
            "t.fromAccount.user.username = :username OR " +
            "t.toAccount.user.username = :username " +
            "ORDER BY t.timestamp DESC")
    List<Transaction> findAllByUser(@Param("username") String username);

    // ✅ Find by Account Number (Both Sender & Receiver)
    @Query("SELECT t FROM Transaction t WHERE " +
            "t.fromAccount.accountNumber = :accountNumber OR " +
            "t.toAccount.accountNumber = :accountNumber " +
            "ORDER BY t.timestamp DESC")
    Page<Transaction> findAllByAccountNumber(@Param("accountNumber") String accountNumber, Pageable pageable);
}