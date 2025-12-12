import SwiftUI
import WebKit
import SafariServices


// MARK: - Blog Model
struct BlogPost: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    //let htmlFileName: String // Reference to HTML file
    let articleURL: String // Endpoint to the savvyme.co/blog URL
    let author: String
    let datePublished: Date
    let category: String
    let readTime: Int // in minutes
    let tags: [String]
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: datePublished)
    }
    
    // Load HTML content from file
    //func loadHTMLContent() -> String {
      //  guard let path = Bundle.main.path(forResource: htmlFileName, ofType: "html"),
        //      let content = try? String(contentsOfFile: path) else {
          //  return "<p>Content not available</p>"
        //}
        //return content
    //}
}

// MARK: - Main Blog View
struct BlogView: View {
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedBlog: BlogPost? = nil
    
    // Blog posts configuration with your actual content
    private let blogPosts: [BlogPost] = [
        BlogPost(
            title: "Save money on fuel",
            summary: "Clever hacks to keep more cash in your pocket",
            //htmlFileName: "fuel-savings", // Will load fuel-savings.html from bundle
            articleURL: "https://besavvyme.substack.com/p/save-money-on-fuel",
            author: "SavvyMe",
            datePublished: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 15)) ?? Date(),
            category: "Save on essentials",
            readTime: 3,
            tags: ["fuel", "essentials", "save"]
        ),
        BlogPost(
            title: "Save big on phone & internet plans",
            summary: "Smart strategies to get the best bang for your buck",
            //htmlFileName: "phone-internet-savings", // Will load phone-internet-savings.html from bundle
            articleURL: "https://besavvyme.substack.com/p/save-big-on-phone-and-internet-plans",
            author: "SavvyMe",
            datePublished: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 16)) ?? Date(),
            category: "Save on essentials",
            readTime: 3,
            tags: ["phone", "internet", "save", "essentials", "plans"]
        ),
        BlogPost(
            title: "Wholesome date ideas that won't break the bank",
            summary: "Fun, romantic and budget-friendly experiences to suit every couple",
            //htmlFileName: "budget-date-ideas", // Will load budget-date-ideas.html from bundle
            articleURL: "https://besavvyme.substack.com/p/wholesome-date-ideas-that-wont-break-the-bank",
            author: "SavvyMe",
            datePublished: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 23)) ?? Date(),
            category: "Lifestyle hacks",
            readTime: 5,
            tags: ["dating", "save", "lifestyle", "relationships"]
        ),
        BlogPost(
            title: "Shop smart and stop overpaying for everything you buy",
            summary: "Spot hidden online deals and save hundreds a year with this 3-step strategy",
            //htmlFileName: "fuel-savings", // Will load fuel-savings.html from bundle
            articleURL: "https://besavvyme.substack.com/p/the-smart-shoppers-guide-stop-overpaying",
            author: "SavvyMe",
            datePublished: Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 24)) ?? Date(),
            category: "Lifestyle hacks",
            readTime: 8,
            tags: ["shopping", "lifestyle", "save"]
        ),
        BlogPost(
            title: "ClassPass: the smarter, cheaper way to achieve your fitness goals",
            summary: "Stretch your body, not your budget – ClassPass vs. Pilates memberships, and other ways to save on fitness",
            //htmlFileName: "fuel-savings", // Will load fuel-savings.html from bundle
            articleURL: "https://besavvyme.substack.com/p/classpass-the-smarter-cheaper-way",
            author: "SavvyMe",
            datePublished: Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 28)) ?? Date(),
            category: "Lifestyle hacks",
            readTime: 3,
            tags: ["fitness", "lifestyle", "save", "pilates"]
        )
    ]
    
    private var categories: [String] {
        let allCategories = Array(Set(blogPosts.map { $0.category })).sorted()
        return ["All"] + allCategories
    }
    
    private var filteredBlogPosts: [BlogPost] {
        let categoryFiltered = selectedCategory == "All" ? blogPosts : blogPosts.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered.sorted { $0.datePublished > $1.datePublished }
        } else {
            return categoryFiltered.filter { post in
                post.title.localizedCaseInsensitiveContains(searchText) ||
                post.summary.localizedCaseInsensitiveContains(searchText) ||
                post.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                post.author.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.datePublished > $1.datePublished }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with category filter
                HeaderSection(
                    selectedCategory: $selectedCategory,
                    categories: categories,
                    postCount: filteredBlogPosts.count
                )
                
                // Search bar
                SearchBar(searchText: $searchText)
                
                // Blog posts list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if filteredBlogPosts.isEmpty {
                            EmptyStateView(searchText: searchText)
                        } else {
                            ForEach(filteredBlogPosts) { post in
                                BlogPostCard(post: post) {
                                    selectedBlog = post
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Blog")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedBlog) { post in
                BlogPostDetailView(post: post)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
        }
    }
}

// MARK: - Sub Views

private struct HeaderSection: View {
    @Binding var selectedCategory: String
    let categories: [String]
    let postCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Select category:")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                        }) {
                            Text(category)
                                .font(.subheadline)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCategory)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                    }
                }
            }
            
            HStack {
                Text("\(postCount) \(postCount == 1 ? "article" : "articles")")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

private struct SearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search articles, tags, or authors...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct BlogPostCard: View {
    let post: BlogPost
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with category and read time
                HStack {
                    Text(post.category)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ColorTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ColorTheme.primary.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("\(post.readTime) min")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Title
                Text(post.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                // Summary
                Text(post.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                // Footer with author and date
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("By \(post.author)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(post.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Tags preview (first 2 tags)
                    HStack(spacing: 6) {
                        ForEach(Array(post.tags.prefix(2)), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(3)
                        }
                        
                        if post.tags.count > 2 {
                            Text("+\(post.tags.count - 2)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct EmptyStateView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "book" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "No articles yet" : "No articles found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !searchText.isEmpty {
                Text("Try adjusting your search terms")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Blog Post Detail View

struct BlogPostDetailView: View {
    let post: BlogPost
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        SafariView(url: URL(string: post.articleURL)!)
            .edgesIgnoringSafeArea(.all)
            .onDisappear {
                presentationMode.wrappedValue.dismiss()
            }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}


struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
