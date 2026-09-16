package com.titan.titancorebanking.batch;

import com.titan.titancorebanking.model.Account; // ✅ Correct Import
import org.springframework.batch.item.ItemProcessor;
import java.math.BigDecimal;

public class InterestProcessor implements ItemProcessor<Account, Account> {
    @Override
    public Account process(Account account) {
        if (account.getBalance().compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal interest = account.getBalance().multiply(new BigDecimal("0.05"));
            account.setBalance(account.getBalance().add(interest));
        }
        return account;
    }
}