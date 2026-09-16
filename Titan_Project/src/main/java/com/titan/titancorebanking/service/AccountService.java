package com.titan.titancorebanking.service;

import com.titan.titancorebanking.dto.request.AccountRequest;
import com.titan.titancorebanking.dto.request.TransactionRequest;
import com.titan.titancorebanking.dto.response.TransactionResponse;
import com.titan.titancorebanking.model.Account;
import com.titan.titancorebanking.model.Transaction;
import com.titan.titancorebanking.model.User;
import com.titan.titancorebanking.enums.AccountType;
import com.titan.titancorebanking.enums.AccountStatus;
import com.titan.titancorebanking.enums.Currency;
import com.titan.titancorebanking.enums.TransactionStatus;
import com.titan.titancorebanking.enums.TransactionType;
import com.titan.titancorebanking.repository.AccountRepository;
import com.titan.titancorebanking.repository.TransactionRepository;
import com.titan.titancorebanking.repository.UserRepository;
import com.titan.titancorebanking.utils.AccountNumberUtils;
import com.titan.titancorebanking.service.imple.OtpService;
import com.titan.titancorebanking.service.imple.ExchangeRateService; // ✅ NEW IMPORT
import com.titan.titancorebanking.exception.InsufficientBalanceException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class AccountService {

    private final AccountRepository accountRepository;
    private final TransactionRepository transactionRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final OtpService otpService;
    private final StringRedisTemplate redisTemplate;
    private final ExchangeRateService exchangeRateService; // ✅ Inject Service

    private static final String PIN_ATTEMPT_PREFIX = "PIN:ATTEMPTS:";
    private static final String PIN_LOCK_PREFIX = "PIN:LOCKED:";
    private static final int MAX_ACCOUNTS = 10;
    private static final BigDecimal HIGH_VALUE_LIMIT = new BigDecimal("100000");

    // ... (getMyAccounts, getBalance, getAccountStatement, createAccount នៅដដែល) ...
    // ... Copy method ទាំងនោះមកដាក់នៅទីនេះដូចដើម ...
    // (ដើម្បីកុំឱ្យកូដវែងពេក ខ្ញុំសុំបង្ហាញតែ method createAccount និង transferMoney ដែលសំខាន់)

    @Transactional
    @CacheEvict(value = "user_accounts", key = "#username")
    public Account createAccount(AccountRequest request, String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));

        if (accountRepository.countByUser(user) >= MAX_ACCOUNTS) {
            throw new RuntimeException("⛔ Limit Reached: You can only create " + MAX_ACCOUNTS + " accounts.");
        }

        AccountType type = AccountType.SAVINGS;
        if (request.getAccountType() != null) {
            try {
                type = AccountType.valueOf(request.getAccountType().toUpperCase());
            } catch (IllegalArgumentException e) {
                log.warn("Invalid AccountType: {}. Defaulting to SAVINGS.", request.getAccountType());
            }
        }

        // Handle Currency Enum
        Currency currency = Currency.USD; // Default
        if (request.getCurrency() != null) { // Assuming DTO has this field now
            try {
                currency = Currency.valueOf(request.getCurrency().toUpperCase());
            } catch (Exception e) {
                log.warn("Invalid Currency: {}. Defaulting to USD.", request.getCurrency());
            }
        }

        String newAccountNumber;
        int attempts = 0;
        do {
            newAccountNumber = AccountNumberUtils.generateAccountNumber();
            attempts++;
            if (attempts > 5) throw new RuntimeException("🔥 System Busy: Could not generate unique account number.");
        } while (accountRepository.existsByAccountNumber(newAccountNumber));

        Account account = Account.builder()
                .accountNumber(newAccountNumber)
                .accountType(type)
                .balance(request.getInitialDeposit() != null ? request.getInitialDeposit() : BigDecimal.ZERO)
                .user(user)
                .createdAt(LocalDateTime.now())
                .status(AccountStatus.ACTIVE)
                .currency(currency) // ✅ Use Dynamic Currency
                .build();

        return accountRepository.save(account);
    }

    // ==========================================================
    // 💱 FX TRANSFER LOGIC (UPDATED)
    // ==========================================================
    @Transactional
    public Transaction transferMoney(TransactionRequest request, String currentUsername) {

        // 1. Validate & Fetch User
        User currentUser = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));

        if (!currentUser.isAccountNonLocked()) {
            throw new SecurityException("⛔ ACCOUNT LOCKED");
        }
        if (Boolean.TRUE.equals(redisTemplate.hasKey(PIN_LOCK_PREFIX + currentUsername))) {
            throw new SecurityException("⏳ Too many wrong attempts.");
        }
        if (!passwordEncoder.matches(request.getPin(), currentUser.getPin())) {
            handlePinFailure(currentUsername, currentUser);
            throw new SecurityException("❌ Incorrect PIN!");
        }
        resetPinAttempts(currentUsername);

        // 2. Fetch Accounts
        Account fromAccount = accountRepository.findByAccountNumber(request.getFromAccountNumber())
                .orElseThrow(() -> new IllegalArgumentException("Sender account not found"));

        if (!fromAccount.getUser().getUsername().equals(currentUsername)) {
            throw new SecurityException("⛔ You do not own this sender account!");
        }

        Account toAccount = accountRepository.findByAccountNumber(request.getToAccountNumber())
                .orElseThrow(() -> new IllegalArgumentException("Receiver account not found"));

        // 3. Balance Check (Source Currency)
        if (fromAccount.getBalance().compareTo(request.getAmount()) < 0) {
            throw new InsufficientBalanceException("Insufficient Balance! Current: " + fromAccount.getBalance());
        }

        // 4. 💱 FX CALCULATION
        BigDecimal sourceAmount = request.getAmount();
        BigDecimal targetAmount = sourceAmount;

        if (fromAccount.getCurrency() != toAccount.getCurrency()) {
            log.info("💱 FX Transfer: {} -> {}", fromAccount.getCurrency(), toAccount.getCurrency());
            targetAmount = exchangeRateService.convert(sourceAmount, fromAccount.getCurrency(), toAccount.getCurrency());
        }

        // 5. Create Transaction Record (Now we have all data)
        Transaction tx = Transaction.builder()
                .transactionType(TransactionType.TRANSFER)
                .amount(sourceAmount) // Record source amount
                .fromAccount(fromAccount) // ✅ Set immediately
                .toAccount(toAccount)     // ✅ Set immediately
                .timestamp(LocalDateTime.now())
                .status(TransactionStatus.PROCESSING)
                .note(request.getNote() + (fromAccount.getCurrency() != toAccount.getCurrency() ? " [FX Rate Applied]" : ""))
                .build();

        tx = transactionRepository.save(tx); // Save once

        try {
            // 6. Execute Transfer
            fromAccount.setBalance(fromAccount.getBalance().subtract(sourceAmount));
            toAccount.setBalance(toAccount.getBalance().add(targetAmount)); // ✅ Add converted amount

            accountRepository.save(fromAccount);
            accountRepository.save(toAccount);

            tx.setStatus(TransactionStatus.SUCCESS);
            transactionRepository.save(tx); // Update Status

        } catch (Exception e) {
            tx.setStatus(TransactionStatus.FAILED);
            tx.setNote("Failure: " + e.getMessage());
            transactionRepository.save(tx);
            throw e;
        }

        return tx;
    }

    // ... (Helper methods: handlePinFailure, etc. នៅដដែល) ...
    private void handlePinFailure(String username, User user) {
        String key = PIN_ATTEMPT_PREFIX + username;
        Long attempts = redisTemplate.opsForValue().increment(key);
        if (attempts != null && attempts == 1) redisTemplate.expire(key, Duration.ofDays(1));
        if (attempts != null && attempts == 5) redisTemplate.opsForValue().set(PIN_LOCK_PREFIX + username, "LOCKED", Duration.ofMinutes(5));
        if (attempts != null && attempts >= 7) { user.setAccountNonLocked(false); userRepository.save(user); redisTemplate.delete(key); }
    }
    private void resetPinAttempts(String username) { redisTemplate.delete(PIN_ATTEMPT_PREFIX + username); }

    // Helper to keep code clean - add missing methods back if needed
    @Transactional(readOnly = true)
    public List<Account> getMyAccounts(String username) { return accountRepository.findByUserUsername(username); }
    @Transactional(readOnly = true)
    public BigDecimal getBalance(String accountNumber) {
        return accountRepository.findByAccountNumber(accountNumber).map(Account::getBalance).orElse(BigDecimal.ZERO);
    }
}