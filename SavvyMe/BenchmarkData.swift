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
    let mortgageBalanceGroup: String
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
    let finalBenchmarkValue: Double
    let finalBenchmarkBasis: String
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
    static let shared = BenchmarkDataManager()

    private var benchmarkData: [BenchmarkData] = []
    private var benchmarkDataBySubcategory: [String: [BenchmarkData]] = [:]

    private init() {
        loadBenchmarkData()
    }
    
    private func loadBenchmarkData() {
        benchmarkData.removeAll(keepingCapacity: true)
        benchmarkDataBySubcategory.removeAll(keepingCapacity: true)

        guard let path = Bundle.main.path(forResource: "06_HOUSEHOLD_BENCHMARK_STATISTICS", ofType: "csv"),
              let content = try? String(contentsOfFile: path) else {
            print("Could not load benchmark data file")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return }

        let header = parseCSVLine(lines[0]).map { $0.replacingOccurrences(of: "\u{feff}", with: "") }
        let columnMap = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element, $0.offset) })
        
        // Skip header row
        for line in lines.dropFirst() {
            if !line.isEmpty {
                if let data = parseBenchmarkLine(line, columnMap: columnMap) {
                    benchmarkData.append(data)
                    benchmarkDataBySubcategory[data.expenseSubcategory, default: []].append(data)
                }
            }
        }
        
        print("Loaded \(benchmarkData.count) benchmark records")
    }
    
    private func parseBenchmarkLine(_ line: String, columnMap: [String: Int]) -> BenchmarkData? {
        let components = parseCSVLine(line)
        guard !components.isEmpty else { return nil }

        func value(for column: String) -> String? {
            guard let index = columnMap[column], index < components.count else { return nil }
            return components[index].replacingOccurrences(of: "\"", with: "")
        }

        func numericValue(for columns: [String]) -> Double? {
            for column in columns {
                if let raw = value(for: column), let parsed = Double(raw) {
                    return parsed
                }
            }
            return nil
        }
        
        // Parse numeric values with proper handling of quoted numbers
        guard let state = value(for: "STATE"),
              let numPersonsOver15Text = value(for: "NUM_PERSONS_OVER_15"),
              let numPersonsOver15 = Int(numPersonsOver15Text),
              let numDependentsUnder15Text = value(for: "NUM_DEPENDENTS_UNDER_15"),
              let numDependentsUnder15 = Int(numDependentsUnder15Text),
              let disposableIncome = value(for: "DISPOSABLE_INCOME"),
              let expenseSubcategory = value(for: "SavvyMe expense subcategory"),
              let expenseCategory = value(for: "SavvyMe expense category"),
              let yearText = value(for: "Year"),
              let year = Int(yearText),
              let weeklyHouseholdSpend = numericValue(for: ["final_benchmark_value", "Weekly household spend", "avg_spend"]),
              let p10 = numericValue(for: ["p10"]),
              let p20 = numericValue(for: ["p20"]),
              let p30 = numericValue(for: ["p30"]),
              let p40 = numericValue(for: ["p40"]),
              let p50 = numericValue(for: ["p50"]),
              let p60 = numericValue(for: ["p60"]),
              let p70 = numericValue(for: ["p70"]),
              let p80 = numericValue(for: ["p80"]),
              let p90 = numericValue(for: ["p90"]),
              let numHouseholdsText = value(for: "num_households"),
              let numHouseholds = Int(numHouseholdsText) else {
            return nil
        }

        let percentileAvail = (value(for: "percentile_avail") ?? "FALSE").uppercased() == "TRUE"
        let finalBenchmarkValue = numericValue(for: ["final_benchmark_value", "Weekly household spend", "avg_spend"]) ?? weeklyHouseholdSpend
        let finalBenchmarkBasis = value(for: "final_benchmark_basis") ?? ""
        let mortgageBalanceGroup = value(for: "MORTGAGE_BALANCE_GROUP") ?? "Any"

        return BenchmarkData(
            state: state,
            numPersonsOver15: numPersonsOver15,
            numDependentsUnder15: numDependentsUnder15,
            disposableIncome: disposableIncome,
            mortgageBalanceGroup: mortgageBalanceGroup,
            expenseSubcategory: expenseSubcategory,
            expenseCategory: expenseCategory,
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
            percentileAvail: percentileAvail,
            finalBenchmarkValue: finalBenchmarkValue,
            finalBenchmarkBasis: finalBenchmarkBasis
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
    
    // New method for getting benchmark amount for budget suggestions
    func getBenchmarkAmount(
        for subcategory: String,
        state: String,
        adultsCount: Int,
        childrenCount: Int,
        incomeRange: String,
        mortgageBalanceGroup: String
    ) -> Double {
        // Map income range to benchmark format
        let benchmarkIncomeRange = mapIncomeToBenchmarkFormat(incomeRange)
        
        // Get the display name for the subcategory to match with benchmark data
        let benchmarkSubcategoryName = AppCategories.spendingDisplayNames[subcategory] ?? subcategory
        
        // Find matching benchmark
        if let benchmark = findMatchingBenchmark(
            state: state,
            adultsCount: adultsCount,
            childrenCount: childrenCount,
            incomeRange: benchmarkIncomeRange,
            mortgageBalanceGroup: mortgageBalanceGroup,
            subcategory: benchmarkSubcategoryName
        ) {
            return benchmark.finalBenchmarkValue
        }
        
        return 0
    }
    
    // Make findMatchingBenchmark public so it can be used by other methods
    func findMatchingBenchmark(
        state: String,
        adultsCount: Int,
        childrenCount: Int,
        incomeRange: String,
        mortgageBalanceGroup: String,
        subcategory: String
    ) -> BenchmarkData? {
        let candidates = benchmarkDataBySubcategory[subcategory] ?? []

        // First try exact match
        if let exact = candidates.first(where: {
            $0.state == state &&
            $0.numPersonsOver15 == adultsCount &&
            $0.numDependentsUnder15 == childrenCount &&
            $0.disposableIncome == incomeRange &&
            ($0.mortgageBalanceGroup == mortgageBalanceGroup || $0.mortgageBalanceGroup == "Any")
        }) {
            return exact
        }

        // Try without state constraint
        if let anyState = candidates.first(where: {
            $0.numPersonsOver15 == adultsCount &&
            $0.numDependentsUnder15 == childrenCount &&
            $0.disposableIncome == incomeRange &&
            ($0.mortgageBalanceGroup == mortgageBalanceGroup || $0.mortgageBalanceGroup == "Any")
        }) {
            return anyState
        }

        // Try with any household composition
        if let anyHousehold = candidates.first(where: {
            $0.disposableIncome == incomeRange &&
            ($0.mortgageBalanceGroup == mortgageBalanceGroup || $0.mortgageBalanceGroup == "Any")
        }) {
            return anyHousehold
        }

        // Set national, single person household as default
        return candidates.first(where: {
            $0.state == "Any" &&
            $0.numPersonsOver15 == 1 &&
            $0.numDependentsUnder15 == 0 &&
            $0.disposableIncome == "Any" &&
            ($0.mortgageBalanceGroup == mortgageBalanceGroup || $0.mortgageBalanceGroup == "Any")
        })
    }
    
    func getBenchmarkComparisons(
        userState: String,
        adultsCount: Int,
        childrenCount: Int,
        incomeRange: String,
        mortgageBalanceGroup: String,
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
                    mortgageBalanceGroup: mortgageBalanceGroup,
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
        return AppCategories.spending
    }
    
    private func getBenchmarkSubcategoryName(_ subcategory: String) -> String {
        let mapping: [String: String] = AppCategories.spendingDisplayNames
        return mapping[subcategory] ?? subcategory
    }
    
    private func convertToWeekly(_ amount: Double, frequency: String) -> Double {
        return amount * frequencyMultiplier(from: frequency) / frequencyMultiplier(from: "Weekly")
    }
    
    private func createComparison(
        category: String,
        subcategory: String,
        userWeeklyAmount: Double,
        benchmark: BenchmarkData
    ) -> UserBenchmarkComparison {
        
        let benchmarkAmount = benchmark.finalBenchmarkValue
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

    var mortgageBalanceGroups: [String] {
        let preferredOrder = ["Any", "< 200k", "200k-500k", ">500k"]
        let availableGroups = Set(
            benchmarkData
                .map { $0.mortgageBalanceGroup }
                .filter { !$0.isEmpty && $0.lowercased() != "no mortgage" }
        )

        let orderedAvailable = preferredOrder.filter { group in
            group == "Any" || availableGroups.contains(group)
        }

        let remaining = availableGroups
            .filter { !preferredOrder.contains($0) }
            .sorted()

        return orderedAvailable + remaining
    }
}
