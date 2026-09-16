package com.titan.adapter.iso20022;

import jakarta.xml.bind.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * ISO 20022 pacs.008.001.08 — FI to FI Customer Credit Transfer
 * Used for SWIFT cross-border wire transfers replacing legacy MT103.
 */
@Data
@XmlRootElement(name = "Document", namespace = "urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08")
@XmlAccessorType(XmlAccessType.FIELD)
public class Pacs008Document {

    @XmlElement(name = "FIToFICstmrCdtTrf", required = true)
    private FIToFICustomerCreditTransfer fiToFiCstmrCdtTrf;

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class FIToFICustomerCreditTransfer {
        @XmlElement(name = "GrpHdr", required = true)
        private GroupHeader grpHdr;

        @XmlElement(name = "CdtTrfTxInf", required = true)
        private CreditTransferTransactionInfo cdtTrfTxInf;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class GroupHeader {
        @XmlElement(name = "MsgId")   private String msgId;
        @XmlElement(name = "CreDtTm") private String creDtTm;
        @XmlElement(name = "NbOfTxs") private int nbOfTxs;
        @XmlElement(name = "SttlmInf") private SettlementInstruction sttlmInf;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class SettlementInstruction {
        @XmlElement(name = "SttlmMtd") private String sttlmMtd; // e.g. "CLRG"
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class CreditTransferTransactionInfo {
        @XmlElement(name = "PmtId")    private PaymentIdentification pmtId;
        @XmlElement(name = "IntrBkSttlmAmt") private ActiveCurrencyAmount intrBkSttlmAmt;
        @XmlElement(name = "IntrBkSttlmDt")  private String intrBkSttlmDt;
        @XmlElement(name = "Dbtr")     private PartyIdentification dbtr;
        @XmlElement(name = "DbtrAcct") private CashAccount dbtrAcct;
        @XmlElement(name = "DbtrAgt")  private BranchAndFinancialInstitution dbtrAgt;
        @XmlElement(name = "Cdtr")     private PartyIdentification cdtr;
        @XmlElement(name = "CdtrAcct") private CashAccount cdtrAcct;
        @XmlElement(name = "CdtrAgt")  private BranchAndFinancialInstitution cdtrAgt;
        @XmlElement(name = "RmtInf")   private RemittanceInformation rmtInf;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class PaymentIdentification {
        @XmlElement(name = "InstrId") private String instrId;
        @XmlElement(name = "EndToEndId") private String endToEndId;
        @XmlElement(name = "UETR") private String uetr; // Unique End-to-End Transaction Reference
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class ActiveCurrencyAmount {
        @XmlAttribute(name = "Ccy") private String ccy;
        @XmlValue private BigDecimal value;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class PartyIdentification {
        @XmlElement(name = "Nm") private String nm;
        @XmlElement(name = "PstlAdr") private PostalAddress pstlAdr;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class PostalAddress {
        @XmlElement(name = "Ctry") private String ctry;
        @XmlElement(name = "AdrLine") private String adrLine;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class CashAccount {
        @XmlElement(name = "Id") private AccountIdentification id;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class AccountIdentification {
        @XmlElement(name = "IBAN") private String iban;
        @XmlElement(name = "Othr") private OtherAccountIdentification othr;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class OtherAccountIdentification {
        @XmlElement(name = "Id") private String id;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class BranchAndFinancialInstitution {
        @XmlElement(name = "FinInstnId") private FinancialInstitutionIdentification finInstnId;
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class FinancialInstitutionIdentification {
        @XmlElement(name = "BICFI") private String bicfi; // BIC code e.g. "ACLBKHPP"
    }

    @Data
    @XmlAccessorType(XmlAccessType.FIELD)
    public static class RemittanceInformation {
        @XmlElement(name = "Ustrd") private String ustrd; // Unstructured remittance info
    }
}
