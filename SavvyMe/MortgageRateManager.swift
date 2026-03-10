import Foundation

struct RBAMortgageRate: Codable {
    let asAtMonth: String
    let ownerOccupierNewPIRatePct: Double
    let ownerOccupierNewAllRatePct: Double
    let sourceTable: String
    let sourceURL: String

    enum CodingKeys: String, CodingKey {
        case asAtMonth = "as_at_month"
        case ownerOccupierNewPIRatePct = "owner_occupier_new_pi_rate_pct"
        case ownerOccupierNewAllRatePct = "owner_occupier_new_all_rate_pct"
        case sourceTable = "source_table"
        case sourceURL = "source_url"
    }
}

final class MortgageRateManager {
    static let shared = MortgageRateManager()

    private(set) var currentRate: RBAMortgageRate?

    private init() {
        loadCurrentRate()
    }

    func loadCurrentRate() {
        guard let url = Bundle.main.url(forResource: "rba_mortgage_rates", withExtension: "json") else {
            print("Could not find rba_mortgage_rates.json in bundle")
            currentRate = nil
            return
        }

        do {
            let data = try Data(contentsOf: url)
            currentRate = try JSONDecoder().decode(RBAMortgageRate.self, from: data)
        } catch {
            print("Could not decode rba_mortgage_rates.json: \(error)")
            currentRate = nil
        }
    }

    func monthlyPrincipalAndInterestPayment(loanAmount: Double, loanYears: Int) -> Double? {
        guard loanAmount > 0,
              loanYears > 0,
              let annualRatePct = currentRate?.ownerOccupierNewPIRatePct else {
            return nil
        }

        let monthlyRate = (annualRatePct / 100) / 12
        let numberOfPayments = Double(loanYears * 12)

        if monthlyRate == 0 {
            return loanAmount / numberOfPayments
        }

        let growthFactor = pow(1 + monthlyRate, numberOfPayments)
        let repayment = loanAmount * (monthlyRate * growthFactor) / (growthFactor - 1)
        return repayment
    }

    func weeklyPrincipalAndInterestPayment(loanAmount: Double, loanYears: Int) -> Double? {
        guard let monthly = monthlyPrincipalAndInterestPayment(loanAmount: loanAmount, loanYears: loanYears) else {
            return nil
        }

        return monthly * 12 / 52
    }
}
