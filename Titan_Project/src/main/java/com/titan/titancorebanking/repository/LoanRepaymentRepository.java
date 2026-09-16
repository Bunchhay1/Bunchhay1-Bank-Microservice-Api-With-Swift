package com.titan.titancorebanking.repository;

import com.titan.titancorebanking.model.LoanRepayment; // ✅ Correct Import
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface LoanRepaymentRepository extends JpaRepository<LoanRepayment, Long> {
    List<LoanRepayment> findByLoan_Id(Long loanId);
}