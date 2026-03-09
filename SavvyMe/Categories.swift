// Categories.swift
import Foundation

struct AppCategories {
    static let all: [String: [String]] = [
        "Home": ["mortgage", "rent", "homeInsurance", "electricity", "gas", "water", "phoneInternet", "furniture", "otherHome"],
        "Daily living": ["groceries", "restaurants", "medical", "healthInsurance", "education", "childCare", "petCare", "otherDailyLiving"],
        "Transport": ["fuel", "servicing", "regoInsurance", "publicTransport", "otherTransport"],
        "Entertainment & personal": ["streaming", "electronics", "concerts", "gymClubs", "clothing", "salonBeauty", "holidays", "otherPersonal"],
        "Income": ["salary", "investment", "interest", "otherIncome"]
    ]
    
    static let spending: [String: [String]] = {
        return all.filter { $0.key != "Income" }
    }()
    
    static let income: [String: [String]] = {
        return all.filter { $0.key == "Income" }
    }()
    
    static let spendingOrder: [String] = ["Home", "Daily living", "Transport", "Entertainment & personal"]
    static let incomeOrder: [String] = ["Income"]
    
    static let spendingDisplayNames: [String: String] = [
        // Home
        "mortgage": "Mortgage repayments",
        "rent": "Rent",
        "homeInsurance": "Home insurance",
        "electricity": "Electricity",
        "gas": "Gas",
        "water": "Water",
        "phoneInternet": "Phone & internet",
        "furniture": "Furniture",
        "otherHome": "Other home",
        
        // Daily living
        "groceries": "Groceries",
        "restaurants": "Restaurants and takeaway",
        "medical": "Medical services",
        "healthInsurance": "Health insurance",
        "education": "Education",
        "childCare": "Child care",
        "petCare": "Pet care",
        "otherDailyLiving": "Other daily living",
        
        // Transport
        "fuel": "Fuel",
        "servicing": "Servicing",
        "regoInsurance": "Rego/insurance",
        "publicTransport": "Public transport",
        "otherTransport": "Other transport",
        
        // Entertainment & personal
        "streaming": "Streaming services",
        "electronics": "Electronics",
        "concerts": "Concert/shows",
        "gymClubs": "Gym/clubs",
        "clothing": "Clothing",
        "salonBeauty": "Salon & beauty",
        "holidays": "Holidays",
        "otherPersonal": "Other entertainment & personal"
    ]
    
    static let incomeDisplayNames: [String: String] = [
        // Income
        "salary": "Salary",
        "investment": "Investment",
        "interest": "Interest",
        "otherIncome": "Other income"
    ]
}
