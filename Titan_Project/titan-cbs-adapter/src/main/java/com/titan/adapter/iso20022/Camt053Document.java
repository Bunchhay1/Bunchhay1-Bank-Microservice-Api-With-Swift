package com.titan.adapter.iso20022;

import jakarta.xml.bind.annotation.*;
import lombok.Data;
import java.math.BigDecimal;

/**
 * ISO 20022 camt.053.001.08 — Bank to Customer Statement
 * Used for cash management reporting (replaces MT940/MT950).
 */
@Data
@XmlRootElement(name = "Document", namespace = "urn:iso:std:iso:20022:tech:xsd:camt.053.001.08")
@XmlAccessorType(XmlAccessType.FIELD)
public class Camt053Document {

    @XmlElement(name = "BkToCstmrStmt", required = true)
    private BankToCustomerStatement bkToCstmrStmt;

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class BankToCustomerStatement {
        @XmlElement(name = "GrpHdr", required = true)
        private GroupHeader grpHdr;

        @XmlElement(name = "Stmt", required = true)
        private AccountStatement stmt;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class GroupHeader {
        @XmlElement(name = "MsgId")    private String msgId;
        @XmlElement(name = "CreDtTm")  private String creDtTm;
        @XmlElement(name = "MsgPgntn") private MessagePagination msgPgntn;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class MessagePagination {
        @XmlElement(name = "PgNb")   private int pgNb;
        @XmlElement(name = "LastPgInd") private boolean lastPgInd;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class AccountStatement {
        @XmlElement(name = "Id")     private String id;
        @XmlElement(name = "Acct")   private CashAccount acct;
        @XmlElement(name = "Bal")    private Balance bal;
        @XmlElement(name = "Ntry")   private java.util.List<ReportEntry> ntry;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class CashAccount {
        @XmlElement(name = "Id") private AccountIdentification id;
        @XmlElement(name = "Ccy") private String ccy;
        @XmlElement(name = "Ownr") private PartyIdentification ownr;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class AccountIdentification {
        @XmlElement(name = "IBAN") private String iban;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class PartyIdentification {
        @XmlElement(name = "Nm") private String nm;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class Balance {
        @XmlElement(name = "Tp")  private BalanceType tp;
        @XmlElement(name = "Amt") private ActiveOrHistoricCurrencyAmount amt;
        @XmlElement(name = "CdtDbtInd") private String cdtDbtInd; // CRDT or DBIT
        @XmlElement(name = "Dt")  private DateAndDateTimeChoice dt;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class BalanceType {
        @XmlElement(name = "CdOrPrtry") private CodeOrProprietary cdOrPrtry;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class CodeOrProprietary {
        @XmlElement(name = "Cd") private String cd; // e.g. "CLBD" = Closing Balance
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class ActiveOrHistoricCurrencyAmount {
        @XmlAttribute(name = "Ccy") private String ccy;
        @XmlValue private BigDecimal value;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class DateAndDateTimeChoice {
        @XmlElement(name = "Dt") private String dt;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class ReportEntry {
        @XmlElement(name = "Amt")       private ActiveOrHistoricCurrencyAmount amt;
        @XmlElement(name = "CdtDbtInd") private String cdtDbtInd;
        @XmlElement(name = "Sts")       private EntryStatus sts;
        @XmlElement(name = "BookgDt")   private DateAndDateTimeChoice bookgDt;
        @XmlElement(name = "NtryDtls")  private EntryDetails ntryDtls;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class EntryStatus {
        @XmlElement(name = "Cd") private String cd; // e.g. "BOOK"
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class EntryDetails {
        @XmlElement(name = "TxDtls") private TransactionDetails txDtls;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class TransactionDetails {
        @XmlElement(name = "Refs")   private TransactionReferences refs;
        @XmlElement(name = "RmtInf") private RemittanceInformation rmtInf;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class TransactionReferences {
        @XmlElement(name = "EndToEndId") private String endToEndId;
        @XmlElement(name = "UETR") private String uetr;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class RemittanceInformation {
        @XmlElement(name = "Ustrd") private String ustrd;
    }
}
