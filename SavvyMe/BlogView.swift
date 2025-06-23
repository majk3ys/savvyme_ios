import SwiftUI
import WebKit

// MARK: - Blog Model
struct BlogPost: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let htmlFileName: String // Reference to HTML file
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
    func loadHTMLContent() -> String {
        guard let path = Bundle.main.path(forResource: htmlFileName, ofType: "html"),
              let content = try? String(contentsOfFile: path) else {
            return "<p>Content not available</p>"
        }
        return content
    }
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
            htmlFileName: "fuel-savings", // Will load fuel-savings.html from bundle
            articleURL: "20250215-saving-money-on-fuel.html",
            author: "Melina Mackey",
            datePublished: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 15)) ?? Date(),
            category: "Save on essentials",
            readTime: 3,
            tags: ["fuel", "essentials", "save"]
        ),
        BlogPost(
            title: "Save big on phone & internet plans",
            summary: "Smart strategies to get the best bang for your buck",
            htmlFileName: "phone-internet-savings", // Will load phone-internet-savings.html from bundle
            articleURL: "20250216-saving-money-on-phone-internet-plans.html",
            author: "Xinyu Shi",
            datePublished: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 16)) ?? Date(),
            category: "Save on essentials",
            readTime: 3,
            tags: ["phone", "internet", "save", "essentials", "plans"]
        ),
        BlogPost(
            title: "Wholesome date ideas that won't break the bank",
            summary: "Fun, romantic and budget-friendly experiences to suit every couple",
            htmlFileName: "budget-date-ideas", // Will load budget-date-ideas.html from bundle
            articleURL: "20250223-affordable-romantic-date-ideas.html",
            author: "Melina Mackey & Xinyu Shi",
            datePublished: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 23)) ?? Date(),
            category: "Lifestyle hacks",
            readTime: 5,
            tags: ["dating", "save", "lifestyle", "relationships"]
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
    @State private var htmlContent: String = ""
    @State private var isLoading = true
    @State private var isSharing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    // Category and read time
                    HStack {
                        Text(post.category)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ColorTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ColorTheme.primary.opacity(0.1))
                            .cornerRadius(6)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.subheadline)
                            Text("\(post.readTime) min read")
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    // Title
                    Text(post.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Author and date
                    HStack {
                        Text("By \(post.author)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(post.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(post.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 1) // Prevent clipping
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Content
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading content...")
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    }
                } else {
                    HTMLContentView(htmlContent: htmlContent)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isSharing = true
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .padding()
                    .foregroundColor(.primary)
                }
            }
            .onAppear {
                loadContent()
            }
            .sheet(isPresented: $isSharing) {
                let shareText = "\(post.title)\n\nhttps://savvyme.co/blog/\(post.articleURL)"
                ShareSheet(items: [shareText])
            }
        }
    }
    
    private func loadContent() {
        htmlContent = post.loadHTMLContent()
        isLoading = false
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - HTML Content View

struct HTMLContentView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Enhanced HTML with proper styling
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    margin: 0;
                    padding: 20px;
                    background-color: transparent;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    color: #1a1a1a;
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                }
                
                h1 { font-size: 28px; }
                h2 { font-size: 24px; }
                h3 { font-size: 20px; }
                h4 { font-size: 18px; }
                
                p {
                    margin-bottom: 16px;
                    font-size: 16px;
                }
                
                ul, ol {
                    margin-bottom: 16px;
                    padding-left: 24px;
                }
                
                li {
                    margin-bottom: 8px;
                    font-size: 16px;
                }
                
                blockquote {
                    border-left: 4px solid #007AFF;
                    margin: 16px 0;
                    padding: 16px 20px;
                    background-color: #f8f9fa;
                    border-radius: 4px;
                    font-style: italic;
                }
                
                code {
                    background-color: #f8f9fa;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Monaco, monospace;
                    font-size: 14px;
                }
                
                pre {
                    background-color: #f8f9fa;
                    padding: 16px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 16px 0;
                }
                
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                
                a:hover {
                    text-decoration: underline;
                }
                
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 16px 0;
                }
                
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 16px 0;
                    font-size: 14px;
                }
                
                th, td {
                    border: 1px solid #ddd;
                    padding: 8px 12px;
                    text-align: left;
                }
                
                th {
                    background-color: #f8f9fa;
                    font-weight: 600;
                }
                
                .italic-note {
                    font-style: italic;
                    color: #666;
                    font-size: 14px;
                }
                
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #f2f2f7;
                        background-color: transparent;
                    }
                    
                    h1, h2, h3, h4, h5, h6 {
                        color: #f2f2f7;
                    }
                    
                    blockquote {
                        background-color: #1c1c1e;
                        border-left-color: #007AFF;
                    }
                    
                    code, pre {
                        background-color: #1c1c1e;
                        color: #f2f2f7;
                    }
                    
                    th {
                        background-color: #1c1c1e;
                    }
                    
                    th, td {
                        border-color: #48484a;
                    }
                    
                    .italic-note {
                        color: #8e8e93;
                    }
                }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
