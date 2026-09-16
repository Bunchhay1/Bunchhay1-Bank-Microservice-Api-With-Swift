package com.titan.loans;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class TitanLoansServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(TitanLoansServiceApplication.class, args);
    }
}
