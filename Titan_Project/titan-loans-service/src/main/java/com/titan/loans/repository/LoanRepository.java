package com.titan.loans.repository;

import com.titan.loans.enums.LoanStatus;
import com.titan.loans.model.Loan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LoanRepository extends JpaRepository<Loan, Long> {

    List<Loan> findByUsername(String username);

    List<Loan> findByAccountId(Long accountId);

    List<Loan> findByStatus(LoanStatus status);

    List<Loan> findByAccountNumber(String accountNumber);
}
