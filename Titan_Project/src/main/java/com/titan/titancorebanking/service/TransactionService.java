package com.titan.titancorebanking.service;

import com.titan.titancorebanking.dto.request.TransactionRequest;
import com.titan.titancorebanking.model.Account;
import com.titan.titancorebanking.model.Transaction;
import com.titan.titancorebanking.enums.TransactionStatus;
import com.titan.titancorebanking.enums.TransactionType;
import com.titan.titancorebanking.enums.AccountType;
import com.titan.titancorebanking.repository.AccountRepository;
import com.titan.titancorebanking.repository.TransactionRepository;
import com.titan.titancorebanking.service.imple.ExchangeRateService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class TransactionService {

    private final TransactionRepository transactionRepository;
    private final AccountRepository accountRepository;
    private final PasswordEncoder passwordEncoder;
    private final ExchangeRateService exchangeRateService;

    // ⚙️ CONSTANTS
    private static final BigDecimal STANDARD_FEE = new BigDecimal("0.50");

    // ==================================================================================
    // 💸 1. TRANSFER (Includes FX & Dynamic Fees)
    // ==================================================================================
    @Transactional
    public Transaction transfer(TransactionRequest request, String currentUsername) {

        Account fromAccount = accountRepository.findByAccountNumber(request.getFromAccountNumber())
                .orElseThrow(() -> new RuntimeException("Sender account not found"));

        if (!fromAccount.getUser().getUsername().equals(currentUsername)) {
            throw new RuntimeException("⛔ You do not own this sender account!");
        }
        if (!passwordEncoder.matches(request.getPin(), fromAccount.getUser().getPin())) {
            throw new RuntimeException("❌ Invalid PIN");
        }

        // Fee Calculation
        BigDecimal fee = BigDecimal.ZERO;
        if (fromAccount.getBalance().compareTo(new BigDecimal("10000")) < 0) {
            fee = STANDARD_FEE;
        }

        // Balance Check
        BigDecimal totalDeduction = request.getAmount().add(fee);
        if (fromAccount.getBalance().compareTo(totalDeduction) < 0) {
            throw new RuntimeException("❌ Insufficient Funds (Amount + Fee: " + totalDeduction + ")");
        }

        Account toAccount = accountRepository.findByAccountNumber(request.getToAccountNumber())
                .orElseThrow(() -> new RuntimeException("Receiver Account not found"));

        // FX Calculation
        BigDecimal targetAmount = request.getAmount();
        String note = request.getNote();

        if (fromAccount.getCurrency() != toAccount.getCurrency()) {
            targetAmount = exchangeRateService.convert(request.getAmount(), fromAccount.getCurrency(), toAccount.getCurrency());
            note += " [FX: " + fromAccount.getCurrency() + " -> " + toAccount.getCurrency() + "]";
        }

        // Execution
        fromAccount.setBalance(fromAccount.getBalance().subtract(totalDeduction));
        toAccount.setBalance(toAccount.getBalance().add(targetAmount));

        accountRepository.save(fromAccount);
        accountRepository.save(toAccount);

        Transaction transaction = Transaction.builder()
                .transactionType(TransactionType.TRANSFER)
                .amount(request.getAmount())
                .fromAccount(fromAccount)
                .toAccount(toAccount)
                .timestamp(LocalDateTime.now())
                .status(TransactionStatus.SUCCESS)
                .note(note + (fee.compareTo(BigDecimal.ZERO) > 0 ? " [Fee: $" + fee + "]" : ""))
                .build();

        return transactionRepository.save(transaction);
    }

    // ==================================================================================
    // 🏧 2. WITHDRAWAL (Includes Overdraft)
    // ==================================================================================
    @Transactional
    public Transaction withdraw(TransactionRequest request, String currentUsername) {
        Account account = accountRepository.findByAccountNumber(request.getFromAccountNumber())
                .orElseThrow(() -> new RuntimeException("Account not found"));

        // Validate Owner
        if (!account.getUser().getUsername().equals(currentUsername)) {
            throw new RuntimeException("⛔ You do not own this account!");
        }
        // Validate PIN
        if (!passwordEncoder.matches(request.getPin(), account.getUser().getPin())) {
            throw new RuntimeException("❌ Invalid PIN");
        }

        BigDecimal maxWithdrawable = account.getBalance();
        if (account.getAccountType() == AccountType.CHECKING && account.getOverdraftLimit() != null) {
            maxWithdrawable = maxWithdrawable.add(account.getOverdraftLimit());
        }

        if (maxWithdrawable.compareTo(request.getAmount()) < 0) {
            throw new RuntimeException("❌ Insufficient funds (Overdraft Limit Exceeded)");
        }

        account.setBalance(account.getBalance().subtract(request.getAmount()));
        accountRepository.save(account);

        Transaction transaction = Transaction.builder()
                .transactionType(TransactionType.WITHDRAWAL)
                .amount(request.getAmount())
                .fromAccount(account)
                .timestamp(LocalDateTime.now())
                .status(TransactionStatus.SUCCESS)
                .note("Withdrawal")
                .build();

        return transactionRepository.save(transaction);
    }

    // ==================================================================================
    // 💰 3. DEPOSIT (Added Back!)
    // ==================================================================================
    @Transactional
    public Transaction deposit(TransactionRequest request) {
        // Deposit អាចដាក់ចូលតាមរយៈ toAccountNumber ឬ accountId
        String targetAccNum = request.getToAccountNumber() != null ? request.getToAccountNumber() : request.getFromAccountNumber();

        Account account = accountRepository.findByAccountNumber(targetAccNum)
                .orElseThrow(() -> new RuntimeException("Account not found"));

        account.setBalance(account.getBalance().add(request.getAmount()));
        accountRepository.save(account);

        Transaction transaction = Transaction.builder()
                .transactionType(TransactionType.DEPOSIT)
                .amount(request.getAmount())
                .toAccount(account)
                .timestamp(LocalDateTime.now())
                .status(TransactionStatus.SUCCESS)
                .note("Deposit")
                .build();

        return transactionRepository.save(transaction);
    }
}