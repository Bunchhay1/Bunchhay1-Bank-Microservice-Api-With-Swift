package com.titan.titancorebanking.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.titan.titancorebanking.dto.request.TransactionRequest;
import com.titan.titancorebanking.dto.response.TransactionResponse;
import com.titan.titancorebanking.entity.Transaction;
import com.titan.titancorebanking.enums.TransactionStatus;
import com.titan.titancorebanking.service.AccountService;
import com.titan.titancorebanking.service.TransactionService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
// ✅ កែប្រែ Import មកប្រើ MockBean វិញ
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class TransactionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    // ✅ កែពី @MockitoBean មកជា @MockBean ដើម្បីឱ្យ CI/CD ដើរ (Spring Boot < 3.4)
    @MockBean
    private TransactionService transactionService;

    @MockBean
    private AccountService accountService;

    // ==========================================
    // 💸 TEST 1: TRANSFER MONEY (SUCCESS)
    // ==========================================
    @Test
    @WithMockUser(username = "sender_user")
    void transfer_ShouldReturn200_WhenSuccess() throws Exception {
        TransactionRequest request = new TransactionRequest();
        request.setFromAccountNumber("111");
        request.setToAccountNumber("222");
        request.setAmount(new BigDecimal("500.00"));
        request.setPin("123456");

        Transaction mockTx = new Transaction();
        mockTx.setStatus(TransactionStatus.SUCCESS);
        mockTx.setAmount(new BigDecimal("500.00"));

        // ✅ ប្រើ transactionService ជំនួស accountService ឱ្យត្រូវតាម Controller Logic
        when(transactionService.transfer(any(TransactionRequest.class), eq("sender_user")))
                .thenReturn(mockTx);

        mockMvc.perform(post("/api/v1/transactions/transfer")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SUCCESS"))
                .andExpect(jsonPath("$.amount").value(500.00));
    }

    // ==========================================
    // 🛑 TEST 2: TRANSFER FAIL (INSUFFICIENT FUNDS)
    // ==========================================
    @Test
    @WithMockUser(username = "poor_user")
    void transfer_ShouldReturn400_WhenInsufficientFunds() throws Exception {
        TransactionRequest request = new TransactionRequest();
        request.setFromAccountNumber("111");
        request.setAmount(new BigDecimal("50000.00"));

        when(transactionService.transfer(any(TransactionRequest.class), eq("poor_user")))
                .thenThrow(new RuntimeException("Insufficient balance"));

        mockMvc.perform(post("/api/v1/transactions/transfer")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Insufficient balance"));
    }

    // ==========================================
    // 💰 TEST 3: DEPOSIT (SUCCESS)
    // ==========================================
    @Test
    @WithMockUser(username = "staff_user")
    void deposit_ShouldReturn200() throws Exception {
        TransactionRequest request = new TransactionRequest();
        request.setToAccountNumber("222");
        request.setAmount(new BigDecimal("1000.00"));

        mockMvc.perform(post("/api/v1/transactions/deposit")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("💰 Deposit Successful!"));
    }

    // ==========================================
    // 🏧 TEST 4: WITHDRAW (SUCCESS)
    // ==========================================
    @Test
    @WithMockUser(username = "rich_user")
    void withdraw_ShouldReturn200() throws Exception {
        TransactionRequest request = new TransactionRequest();
        request.setFromAccountNumber("111");
        request.setAmount(new BigDecimal("200.00"));
        request.setPin("123456");

        mockMvc.perform(post("/api/v1/transactions/withdraw")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("💸 Withdrawal Successful!"));
    }

    // ==========================================
    // 📜 TEST 5: GET HISTORY
    // ==========================================
    @Test
    @WithMockUser(username = "history_user")
    void getHistory_ShouldReturnList() throws Exception {
        TransactionResponse tx1 = TransactionResponse.builder().amount(new BigDecimal("100")).type("DEPOSIT").build();
        TransactionResponse tx2 = TransactionResponse.builder().amount(new BigDecimal("50")).type("WITHDRAWAL").build();

        when(transactionService.getMyTransactions("history_user"))
                .thenReturn(List.of(tx1, tx2));

        mockMvc.perform(get("/api/v1/transactions"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.size()").value(2))
                .andExpect(jsonPath("$[0].amount").value(100));
    }
}