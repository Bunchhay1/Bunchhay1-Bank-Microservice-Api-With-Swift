import Foundation

/// Smart currency converter and exchange rate manager for Titan Banking.
/// Handles dual-currency conversion between US Dollars (USD) and Cambodian Riel (KHR)
/// using standard banking rates (1 USD = 4,100 KHR).
struct SmartCurrencyConverter {
    /// Standard banking exchange rate: 1 USD = 4,100 KHR
    static let defaultUsdToKhrRate: Double = 4100.0

    /// Rate description text for UI display
    static var rateDescription: String {
        "1 USD = 4,100 KHR"
    }

    /// Converts an amount from one currency to another
    static func convert(
        amount: Double,
        from sourceCurrency: String,
        to targetCurrency: String,
        rate: Double = defaultUsdToKhrRate
    ) -> Double {
        let src = sourceCurrency.uppercased()
        let tgt = targetCurrency.uppercased()

        if src == tgt { return amount }

        if src == "USD" && tgt == "KHR" {
            return (amount * rate).rounded()
        } else if src == "KHR" && tgt == "USD" {
            let converted = amount / rate
            return (converted * 100).rounded() / 100.0
        }
        return amount
    }

    /// Converts USD to KHR (e.g. 5.00 USD -> 20,500 KHR)
    static func usdToKhr(_ usd: Double, rate: Double = defaultUsdToKhrRate) -> Double {
        (usd * rate).rounded()
    }

    /// Converts KHR to USD (e.g. 20,500 KHR -> 5.00 USD)
    static func khrToUsd(_ khr: Double, rate: Double = defaultUsdToKhrRate) -> Double {
        let converted = khr / rate
        return (converted * 100).rounded() / 100.0
    }

    /// Formats currency with appropriate symbols and decimal places
    static func format(amount: Double, currency: String) -> String {
        let curr = currency.uppercased()
        if curr == "KHR" {
            let intVal = Int(amount.rounded())
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let formatted = formatter.string(from: NSNumber(value: intVal)) ?? "\(intVal)"
            return "\(formatted) ៛"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return formatter.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
        }
    }

    /// Returns a formatted dual-currency equivalent badge (e.g. "≈ 20,500 ៛" or "≈ $5.00")
    static func dualCurrencyBadge(
        amount: Double,
        currentCurrency: String,
        rate: Double = defaultUsdToKhrRate
    ) -> String {
        guard amount > 0 else { return "" }
        let curr = currentCurrency.uppercased()
        if curr == "USD" {
            let khr = usdToKhr(amount, rate: rate)
            return "≈ \(format(amount: khr, currency: "KHR"))"
        } else {
            let usd = khrToUsd(amount, rate: rate)
            return "≈ \(format(amount: usd, currency: "USD"))"
        }
    }

    /// Detailed conversion breakdown for review and detail screens
    static func conversionSummary(
        amount: Double,
        currency: String,
        rate: Double = defaultUsdToKhrRate
    ) -> (convertedAmount: Double, targetCurrency: String, formattedSource: String, formattedTarget: String) {
        let curr = currency.uppercased()
        if curr == "USD" {
            let khr = usdToKhr(amount, rate: rate)
            return (
                convertedAmount: khr,
                targetCurrency: "KHR",
                formattedSource: format(amount: amount, currency: "USD"),
                formattedTarget: format(amount: khr, currency: "KHR")
            )
        } else {
            let usd = khrToUsd(amount, rate: rate)
            return (
                convertedAmount: usd,
                targetCurrency: "USD",
                formattedSource: format(amount: amount, currency: "KHR"),
                formattedTarget: format(amount: usd, currency: "USD")
            )
        }
    }
}
