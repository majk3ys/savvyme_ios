//
//  BenchmarkData.swift
//  SavvyMe
//
//  Created by Melina Mackey on 23/6/2025.
//


import Foundation

// MARK: - Benchmark Data Models
struct BenchmarkData {
    let state: String
    let numPersonsOver15: Int
    let numDependentsUnder15: Int
    let disposableIncome: String
    let expenseSubcategory: String
    let expenseCategory: String
    let year: Int
    let weeklyHouseholdSpend: Double
    let p10: Double
    let p20: Double
    let p30: Double
    let p40: Double
    let p50: Double
    let p60: Double
    let p70: Double
    let p80: Double
    let p90: Double
    let numHouseholds: Int
    let percentileAvail: Bool
}

struct UserBenchmarkComparison {
    let category: String
    let subcategory: String
    let userAmount: Double
    let benchmarkAmount: Double
    let percentile: Int? // Which percentile the user falls into
    let isAboveAverage: Bool
    let difference: Double // User amount - benchmark amount
    let percentageDifference: Double // (difference / benchmark) * 100
}

// MARK: - Benchmark Data Manager
class BenchmarkDataManager: ObservableObject {
    private var benchmarkData: [BenchmarkData] = []
    
    init() {
        loadBenchmarkData()
    }
    
    private func loadBenchmarkData() {
        guard let path = Bundle.main.path(forResource: "06_HOUSEHOLD_BENCHMARK_STATISTICS", ofType: "csv"),
              let content = try? String(contentsOfFile: path) else {
            print("Could not load benchmark data file")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return }
        
        // Skip header row
        for line in lines.dropFirst() {
            if !line.isEmpty {
                if let data = parseBenchmarkLine(line) {
                    benchmarkData.append(data)
                }
            }
        }
        
        print("Loaded \(benchmarkData.count) benchmark records")
    }
    
    private func parseBenchmarkLine(_ line: String) -> BenchmarkData? {
        let components = parseCSVLine(line)
        guard components.count >= 12 else { return nil }
        
        // Parse numeric values with proper handling of quoted numbers
        guard let numPersonsOver15 = Int(components[1]),
              let numDependentsUnder15 = Int(components[2]),
              let year = Int(components[6]),
              let weeklyHouseholdSpend = Double(components[7]),
              let p10 = Double(components[8]),
              let p20 = Double(components[9]),
              let p30 = Double(components[10]),
              let p40 = Double(components[11]),
              let p50 = Double(components[12]),
              let p60 = Double(components[13]),
              let p70 = Double(components[14]),
              let p80 = Double(components[15]),
              let p90 = Double(components[16]),
              let numHouseholds = Int(components[17]) else {
            return nil
        }
        
        let percentileAvail = components[18].uppercased() == "TRUE"
        
        return BenchmarkData(
            state: components[0],
            numPersonsOver15: numPersonsOver15,
            numDependentsUnder15: numDependentsUnder15,
            disposableIncome: components[3].replacingOccurrences(of: "\"", with: ""),
            expenseSubcategory: components[4],
            expenseCategory: components[5],
            year: year,
            weeklyHouseholdSpend: weeklyHouseholdSpend,
            p10: p10,
            p20: p20,
            p30: p30,
            p40: p40,
            p50: p50,
            p60: p60,
            p70: p70,
            p80: p80,
            p90: p90,
            numHouseholds: numHouseholds,
            percentileAvail: percentileAvail
        )
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField += String(char)
            }
            
            i = line.index(after: i)
        }
        
        // Add the last field
        result.append(currentField.trimmingCharacters(in: .whitespaces))
        
        return result
    }
    
    // MARK: - Public Methods
    func getBenchmarkComparisons(
        userState: String,
        adultsCount: Int,
        childrenCount: Int,
        incomeRange: String,
        userSpending: [String: Double],
        overallFrequency: String
    ) -> [UserBenchmarkComparison] {
        
        var comparisons: [UserBenchmarkComparison] = []
        
        // Map user income range to benchmark format
        let benchmarkIncomeRange = mapIncomeToBenchmarkFormat(incomeRange)
        
        // Group user spending by categories that match benchmark data
        let categoryMapping = getCategoryMapping()
        
        for (userCategory, subcategories) in categoryMapping {
            for subcategory in subcategories {
                guard let userAmount = userSpending[subcategory], userAmount > 0 else { continue }
                
                // Convert user amount to weekly for comparison
                let userWeeklyAmount = convertToWeekly(userAmount, frequency: overallFrequency)
                
                if let benchmark = findMatchingBenchmark(
                    state: userState,
                    adultsCount: adultsCount,
                    childrenCount: childrenCount,
                    incomeRange: benchmarkIncomeRange,
                    subcategory: getBenchmarkSubcategoryName(subcategory)
                ) {
                    let comparison = createComparison(
                        category: userCategory,
                        subcategory: subcategory,
                        userWeeklyAmount: userWeeklyAmount,
                        benchmark: benchmark
                    )
                    comparisons.append(comparison)
                }
            }
        }
        
        return comparisons.sorted { $0.percentageDifference > $1.percentageDifference }
    }
    
    private func mapIncomeToBenchmarkFormat(_ incomeRange: String) -> String {
        switch incomeRange {
        case "Below 25k": return "< 500"
        case "25k-49k": return "500-999"
        case "50k-79k": return "1,000-1,499"
        case "80k-104k": return "1,500-1,999"
        case "105k-129k": return "2,000-2,499"
        case "130k-159k": return "2,500-2,999"
        case "160k-209k": return "3,000-3,999"
        case "210k above": return ">= 4,000"
        default: return "1,000-1,499" // Default fallback
        }
    }
    
    private func getCategoryMapping() -> [String: [String]] {
        return [
            "Home": ["mortgage", "rent", "homeInsurance", "electricity", "gas", "water", "phone", "internet", "furniture", "otherHome"],
            "Daily living": ["groceries", "restaurants", "medical", "healthInsurance", "education", "childCare", "petCare", "otherDailyLiving"],
            "Transport": ["fuel", "servicing", "regoInsurance", "publicTransport", "otherTransport"],
            "Entertainment & personal": ["streaming", "electronics", "concerts", "gymClubs", "clothing", "salonBeauty", "holidays", "otherPersonal"]
        ]
    }
    
    private func getBenchmarkSubcategoryName(_ subcategory: String) -> String {
        let mapping: [String: String] = [
            "mortgage": "Mortgage repayments",
            "rent": "Rent",
            "homeInsurance": "Home insurance",
            "electricity": "Electricity",
            "gas": "Gas",
            "water": "Water",
            "phone": "Phone",
            "internet": "Internet",
            "furniture": "Furniture",
            "otherHome": "Other home",
            "groceries": "Groceries",
            "restaurants": "Restaurants and takeaway",
            "medical": "Medical services",
            "healthInsurance": "Health insurance",
            "education": "Education",
            "childCare": "Child care",
            "petCare": "Pet care",
            "otherDailyLiving": "Other daily living",
            "fuel": "Fuel",
            "servicing": "Servicing",
            "regoInsurance": "Rego/insurance",
            "publicTransport": "Public transport",
            "otherTransport": "Other transport",
            "streaming": "Streaming services",
            "electronics": "Electronics",
            "concerts": "Concert/shows",
            "gymClubs": "Gym/clubs",
            "clothing": "Clothing",
            "salonBeauty": "Salon & beauty",
            "holidays": "Holidays",
            "otherPersonal": "Other entertainment & personal"
        ]
        return mapping[subcategory] ?? subcategory
    }
    
    private func convertToWeekly(_ amount: Double, frequency: String) -> Double {
        switch frequency {
        case "Weekly": return amount
        case "Fortnightly": return amount / 2
        case "Monthly": return amount / 4.33 // Average weeks per month
        case "Quarterly": return amount / 13
        case "Annual": return amount / 52
        default: return amount
        }
    }
    
    private func findMatchingBenchmark(
        state: String,
        adultsCount: Int,
        childrenCount: Int,
        incomeRange: String,
        subcategory: String
    ) -> BenchmarkData? {
        
        // First try exact match
        var matches = benchmarkData.filter {
            $0.state == state &&
            $0.numPersonsOver15 == adultsCount &&
            $0.numDependentsUnder15 == childrenCount &&
            $0.disposableIncome == incomeRange &&
            $0.expenseSubcategory == subcategory
        }
        
        if matches.isEmpty {
            // Try without state constraint
            matches = benchmarkData.filter {
                $0.numPersonsOver15 == adultsCount &&
                $0.numDependentsUnder15 == childrenCount &&
                $0.disposableIncome == incomeRange &&
                $0.expenseSubcategory == subcategory
            }
        }
        
        if matches.isEmpty {
            // Try with any household composition
            matches = benchmarkData.filter {
                $0.disposableIncome == incomeRange &&
                $0.expenseSubcategory == subcategory
            }
        }
        
        return matches.first
    }
    
    private func createComparison(
        category: String,
        subcategory: String,
        userWeeklyAmount: Double,
        benchmark: BenchmarkData
    ) -> UserBenchmarkComparison {
        
        let benchmarkAmount = benchmark.p50 // Use median as benchmark
        let difference = userWeeklyAmount - benchmarkAmount
        let percentageDifference = benchmarkAmount > 0 ? (difference / benchmarkAmount) * 100 : 0
        let isAboveAverage = userWeeklyAmount > benchmarkAmount
        
        // Determine which percentile the user falls into
        let percentile = determinePercentile(userWeeklyAmount, benchmark: benchmark)
        
        return UserBenchmarkComparison(
            category: category,
            subcategory: subcategory,
            userAmount: userWeeklyAmount,
            benchmarkAmount: benchmarkAmount,
            percentile: percentile,
            isAboveAverage: isAboveAverage,
            difference: difference,
            percentageDifference: percentageDifference
        )
    }
    
    private func determinePercentile(_ userAmount: Double, benchmark: BenchmarkData) -> Int? {
        if userAmount <= benchmark.p10 { return 10 }
        else if userAmount <= benchmark.p20 { return 20 }
        else if userAmount <= benchmark.p30 { return 30 }
        else if userAmount <= benchmark.p40 { return 40 }
        else if userAmount <= benchmark.p50 { return 50 }
        else if userAmount <= benchmark.p60 { return 60 }
        else if userAmount <= benchmark.p70 { return 70 }
        else if userAmount <= benchmark.p80 { return 80 }
        else if userAmount <= benchmark.p90 { return 90 }
        else { return 95 } // Above 90th percentile
    }
}