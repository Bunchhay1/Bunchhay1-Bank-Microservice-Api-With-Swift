package com.titan.titancorebanking;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching; // 1. Import កញ្ចប់ Cache
import org.springframework.scheduling.annotation.EnableScheduling;


@SpringBootApplication
@EnableCaching // 2. បើកម៉ាស៊ីន Cache (Redis)

public class TitanCoreBankingApplication {

    public static void main(String[] args) {
        SpringApplication.run(TitanCoreBankingApplication.class, args);
    }

}