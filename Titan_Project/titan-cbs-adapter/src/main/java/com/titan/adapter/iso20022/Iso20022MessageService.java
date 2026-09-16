package com.titan.adapter.iso20022;

import jakarta.xml.bind.JAXBContext;
import jakarta.xml.bind.JAXBException;
import jakarta.xml.bind.Marshaller;
import jakarta.xml.bind.Unmarshaller;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.StringReader;
import java.io.StringWriter;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

/**
 * Task 1: ISO 20022 Message Serializer/Parser
 *
 * Handles:
 *  - pacs.008 (FI-to-FI Credit Transfer) — outbound SWIFT wires
 *  - camt.053 (Bank Statement)            — inbound reconciliation
 *
 * Replaces legacy MT103/MT940 formats.
 */
@Service
@Slf4j
public class Iso20022MessageService {

    private final JAXBContext pacs008Context;
    private final JAXBContext camt053Context;

    public Iso20022MessageService() throws JAXBException {
        this.pacs008Context = JAXBContext.newInstance(Pacs008Document.class);
        this.camt053Context = JAXBContext.newInstance(Camt053Document.class);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // OUTBOUND: Build pacs.008 XML for a cross-border wire
    // ─────────────────────────────────────────────────────────────────────────
    public String buildPacs008(Iso20022TransferRequest req) throws JAXBException {
        var doc = new Pacs008Document();
        var body = new Pacs008Document.FIToFICustomerCreditTransfer();

        // Group Header
        var grpHdr = new Pacs008Document.GroupHeader();
        grpHdr.setMsgId("TITAN-" + UUID.randomUUID().toString().replace("-", "").substring(0, 16).toUpperCase());
        grpHdr.setCreDtTm(LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
        grpHdr.setNbOfTxs(1);
        var sttlm = new Pacs008Document.SettlementInstruction();
        sttlm.setSttlmMtd("CLRG");
        grpHdr.setSttlmInf(sttlm);
        body.setGrpHdr(grpHdr);

        // Transaction Info
        var txInfo = new Pacs008Document.CreditTransferTransactionInfo();

        var pmtId = new Pacs008Document.PaymentIdentification();
        pmtId.setInstrId(req.instructionId());
        pmtId.setEndToEndId(req.endToEndId());
        pmtId.setUetr(UUID.randomUUID().toString()); // SWIFT UETR
        txInfo.setPmtId(pmtId);

        var amt = new Pacs008Document.ActiveCurrencyAmount();
        amt.setCcy(req.currency());
        amt.setValue(req.amount());
        txInfo.setIntrBkSttlmAmt(amt);
        txInfo.setIntrBkSttlmDt(LocalDate.now().toString());

        // Debtor
        var dbtr = new Pacs008Document.PartyIdentification();
        dbtr.setNm(req.debtorName());
        var dbtrAddr = new Pacs008Document.PostalAddress();
        dbtrAddr.setCtry(req.debtorCountry());
        dbtr.setPstlAdr(dbtrAddr);
        txInfo.setDbtr(dbtr);

        var dbtrAcct = new Pacs008Document.CashAccount();
        var dbtrAcctId = new Pacs008Document.AccountIdentification();
        dbtrAcctId.setIban(req.debtorIban());
        dbtrAcct.setId(dbtrAcctId);
        txInfo.setDbtrAcct(dbtrAcct);

        var dbtrAgt = new Pacs008Document.BranchAndFinancialInstitution();
        var dbtrFinId = new Pacs008Document.FinancialInstitutionIdentification();
        dbtrFinId.setBicfi(req.debtorBic());
        dbtrAgt.setFinInstnId(dbtrFinId);
        txInfo.setDbtrAgt(dbtrAgt);

        // Creditor
        var cdtr = new Pacs008Document.PartyIdentification();
        cdtr.setNm(req.creditorName());
        var cdtrAddr = new Pacs008Document.PostalAddress();
        cdtrAddr.setCtry(req.creditorCountry());
        cdtr.setPstlAdr(cdtrAddr);
        txInfo.setCdtr(cdtr);

        var cdtrAcct = new Pacs008Document.CashAccount();
        var cdtrAcctId = new Pacs008Document.AccountIdentification();
        cdtrAcctId.setIban(req.creditorIban());
        cdtrAcct.setId(cdtrAcctId);
        txInfo.setCdtrAcct(cdtrAcct);

        var cdtrAgt = new Pacs008Document.BranchAndFinancialInstitution();
        var cdtrFinId = new Pacs008Document.FinancialInstitutionIdentification();
        cdtrFinId.setBicfi(req.creditorBic());
        cdtrAgt.setFinInstnId(cdtrFinId);
        txInfo.setCdtrAgt(cdtrAgt);

        // Remittance
        var rmtInf = new Pacs008Document.RemittanceInformation();
        rmtInf.setUstrd(req.remittanceInfo());
        txInfo.setRmtInf(rmtInf);

        body.setCdtTrfTxInf(txInfo);
        doc.setFiToFiCstmrCdtTrf(body);

        // Marshal to XML
        Marshaller m = pacs008Context.createMarshaller();
        m.setProperty(Marshaller.JAXB_FORMATTED_OUTPUT, true);
        m.setProperty(Marshaller.JAXB_ENCODING, "UTF-8");
        StringWriter sw = new StringWriter();
        m.marshal(doc, sw);

        log.info("Generated pacs.008 for UETR={}", txInfo.getPmtId().getUetr());
        return sw.toString();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INBOUND: Parse camt.053 XML bank statement
    // ─────────────────────────────────────────────────────────────────────────
    public Camt053Document parseCamt053(String xml) throws JAXBException {
        Unmarshaller u = camt053Context.createUnmarshaller();
        Camt053Document doc = (Camt053Document) u.unmarshal(new StringReader(xml));
        log.info("Parsed camt.053 statement msgId={}", doc.getBkToCstmrStmt().getGrpHdr().getMsgId());
        return doc;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INBOUND: Parse pacs.008 XML (received from correspondent bank)
    // ─────────────────────────────────────────────────────────────────────────
    public Pacs008Document parsePacs008(String xml) throws JAXBException {
        Unmarshaller u = pacs008Context.createUnmarshaller();
        return (Pacs008Document) u.unmarshal(new StringReader(xml));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DTO for building outbound pacs.008
    // ─────────────────────────────────────────────────────────────────────────
    public record Iso20022TransferRequest(
            String instructionId,
            String endToEndId,
            BigDecimal amount,
            String currency,
            String debtorName,
            String debtorIban,
            String debtorBic,
            String debtorCountry,
            String creditorName,
            String creditorIban,
            String creditorBic,
            String creditorCountry,
            String remittanceInfo
    ) {}
}
