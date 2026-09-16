package com.titan.titancorebanking.repository;

import com.titan.titancorebanking.model.Loan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LoanRepository extends JpaRepository<Loan, Long> {

    // ✅ Find loans by Username (Through Account -> User)
    List<Loan> findByAccount_User_Username(String username);

    // ✅ Find loans by Account Number
    List<Loan> findByAccount_AccountNumber(String accountNumber);
}