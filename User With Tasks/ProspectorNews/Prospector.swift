import SwiftUI
import SafariServices
import SDWebImageSwiftUI


struct ProspectorView: View {
    @StateObject private var vm = ProspectorViewModel()
    @State private var openURL: URL?

    var body: some View {
        NavigationStack {

            filterBar
                .padding()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let err = vm.errorText {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    
                        ForEach(vm.filteredArticles) { article in
                            Button {
                                openURL = article.link
                            } label: {
                                ArticleRow(article: article)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            Divider()
                        }

                        if vm.isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding(.vertical, 12)
                        }

                }
                .padding()
            }
            .padding()
            .navigationTitle("ProspectorNow")
            .refreshable { await vm.refreshNewOnly() }
            .task { await vm.startup() }
            .fullScreenCover(item: Binding(
                get: { openURL.map(URLItem.init) },
                set: { openURL = $0?.url }
            )) { item in
                SafariView(url: item.url).ignoresSafeArea()
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProspectorSection.allCases) { section in
                        FilterPill(
                            title: section.title,
                            selected: vm.selectedSection == section
                        ) {
                            vm.select(section: section)
                        }
                    }
                }
            }

            if let subs = vm.availableSubsections, !subs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(
                            title: "All",
                            selected: vm.selectedSubsection == nil
                        ) {
                            vm.select(subsection: nil)
                        }

                        ForEach(subs) { sub in
                            FilterPill(
                                title: sub.title,
                                selected: vm.selectedSubsection == sub
                            ) {
                                vm.select(subsection: sub)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Text(vm.statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await vm.refreshNewOnly() }
                } label: {
                    Text("Update")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.secondary.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
    }
}

struct FilterPill: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    Capsule().fill(selected ? Color.primary.opacity(0.14) : Color.secondary.opacity(0.10))
                )
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}


struct ArticleRow: View {
    let article: ProspectorArticle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let img = article.featuredImageURL {
                WebImage(url: img) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.15))
                }
                .frame(width: 96, height: 72)
                .clipped()
                .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(article.titlePlain)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                if !article.excerptPlain.isEmpty {
                    Text(article.excerptPlain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }


                HStack(spacing: 6) {
                    Text(article.date, style: .date)
                    if let author = article.authorName, !author.isEmpty {
                        Text("• \(author)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}



struct ProspectorArticle: Identifiable, Codable, Equatable {
    let id: Int
    let date: Date
    let link: URL
    let title: String
    let excerpt: String
    let authorName: String?
    let featuredImageURL: URL?
    let categoryIDs: [Int]
}



enum ProspectorSection: String, CaseIterable, Identifiable {
    case all
    case news
    case features
    case opinion
    case qa
    case sportsCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .news: return "News"
        case .features: return "Features"
        case .opinion: return "Opinion"
        case .qa: return "Q+A"
        case .sportsCenter: return "Sports Center"
        }
    }

    var subsections: [ProspectorSubsection] {
        switch self {
        case .all:
            return []
        case .news:
            // Menu: COMMUNITY, READ NEWS, WATCH NEWS, LISTEN NEWS, PHOTO ALBUMS, NEED TO KNOW :contentReference[oaicite:1]{index=1}
            return [
                .init(title: "Community", slugs: ["community"]),
                .init(title: "Read", slugs: ["readnews"]),
                .init(title: "Watch", slugs: ["watchnews"]),
                .init(title: "Listen", slugs: ["listennews"]),
                .init(title: "Photo Albums", slugs: ["photo-albums", "2025-photo-albums", "2024-photo-albums"]),
                .init(title: "Need To Know", slugs: ["need-to-know", "schedules"])
            ]
        case .features:
            // Menu: READ FEATURES, WATCH FEATURES, LISTEN FEATURES :contentReference[oaicite:2]{index=2}
            return [
                .init(title: "Read", slugs: ["readfeatures"]),
                .init(title: "Watch", slugs: ["watchfeatures"]),
                .init(title: "Listen", slugs: ["listenfeatures"])
            ]
        case .opinion:
            // Menu: READ OPINION, WATCH OPINION, LISTEN OPINION, ENTERTAINMENT :contentReference[oaicite:3]{index=3}
            return [
                .init(title: "Read", slugs: ["readopinion"]),
                .init(title: "Watch", slugs: ["watchopinion"]),
                .init(title: "Listen", slugs: ["listenopinion"]),
                .init(title: "Entertainment", slugs: ["entertainment", "arts-and-entertainment"])
            ]
        case .qa:
            // Menu: READ Q+A, WATCH Q+A, LISTEN Q+A :contentReference[oaicite:4]{index=4}
            return [
                .init(title: "Read", slugs: ["readqa", "readq-a", "read-q-a"]),
                .init(title: "Watch", slugs: ["watchqa", "watchq-a", "watch-q-a"]),
                .init(title: "Listen", slugs: ["listenqa", "listenq-a", "listen-q-a"])
            ]
        case .sportsCenter:
            // Menu currently shows SCORES & SCHEDULES :contentReference[oaicite:5]{index=5}
            return [
                .init(title: "Scores & Schedules", slugs: ["scores-schedules", "scores-and-schedules", "schedules"])
            ]
        }
    }

    func matches(article: ProspectorArticle, taxonomy: ProspectorTaxonomy?) -> Bool {
        guard self != .all else { return true }

        // If taxonomy exists, match by known slugs and also by parent slugs.
        if let taxonomy {
            let slugsForSection: [String] = {
                switch self {
                case .all: return []
                case .news: return ["news", "readnews", "watchnews", "listennews", "community", "photo-albums", "2025-photo-albums", "2024-photo-albums", "need-to-know", "schedules"]
                case .features: return ["features", "readfeatures", "watchfeatures", "listenfeatures"]
                case .opinion: return ["opinion", "readopinion", "watchopinion", "listenopinion", "entertainment", "arts-and-entertainment"]
                case .qa: return ["qa", "q-a", "readqa", "watchqa", "listenqa", "readq-a", "watchq-a", "listenq-a"]
                case .sportsCenter: return ["sports-center", "scores-schedules", "scores-and-schedules", "schedules"]
                }
            }()
            return taxonomy.articleHasAnySlug(article, slugs: slugsForSection)
        }

        // Fallback heuristic if taxonomy has not loaded yet
        let path = article.link.path.lowercased()
        switch self {
        case .news: return path.contains("/news/")
        case .features: return path.contains("/features/")
        case .opinion: return path.contains("/opinion/")
        case .qa: return path.contains("/q") && path.contains("a")
        case .sportsCenter: return path.contains("/sports") || path.contains("/scores") || path.contains("/schedules")
        case .all: return true
        }
    }
}

struct ProspectorSubsection: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let slugs: [String]

    func matches(article: ProspectorArticle, taxonomy: ProspectorTaxonomy?) -> Bool {
        if let taxonomy {
            return taxonomy.articleHasAnySlug(article, slugs: slugs)
        }
        let p = article.link.path.lowercased()
        for s in slugs {
            if p.contains("/\(s)/") { return true }
        }
        return false
    }
}



@MainActor
final class ProspectorViewModel: ObservableObject {
    @Published var articles: [ProspectorArticle] = []
    @Published var isLoading = false
    @Published var errorText: String? = nil

    @Published var selectedSection: ProspectorSection = .all
    @Published var selectedSubsection: ProspectorSubsection? = nil

    private let service = ProspectorNowService()
    private let cache = ProspectorPostsCache()
    private let taxonomyCache = ProspectorTaxonomyCache()

    private var taxonomy: ProspectorTaxonomy? = nil

    var availableSubsections: [ProspectorSubsection]? {
        let subs = selectedSection.subsections
        return subs.isEmpty ? nil : subs
    }

    var filteredArticles: [ProspectorArticle] {
        var out = articles
        if selectedSection != .all {
            out = out.filter { selectedSection.matches(article: $0, taxonomy: taxonomy) }
        }
        if let sub = selectedSubsection {
            out = out.filter { sub.matches(article: $0, taxonomy: taxonomy) }
        }
        return out
    }

    var statusLine: String {
        "\(filteredArticles.count)/\(articles.count)"
    }

    func select(section: ProspectorSection) {
        selectedSection = section
        selectedSubsection = nil
    }

    func select(subsection: ProspectorSubsection?) {
        selectedSubsection = subsection
    }

    func startup() async {
        
        if let payload = cache.load() {
            self.articles = payload.articles.sorted(by: { $0.date > $1.date })
        }

        
        self.taxonomy = taxonomyCache.load()

        
        Task { await refreshTaxonomy() }

        
        await refreshNewOnly()
    }

    func refreshNewOnly() async {
        guard !isLoading else { return }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            if articles.isEmpty {
                // First run: fetch all posts, cache them
                let all = try await service.fetchAllPosts(perPage: 100)
                self.articles = all.sorted(by: { $0.date > $1.date })
                cache.save(ProspectorCachePayload(articles: self.articles))
            } else {
                // Later runs: fetch only newer than newest cached date
                let newest = articles.first?.date ?? Date(timeIntervalSince1970: 0)
                let after = newest.addingTimeInterval(-120) // 2 min buffer to avoid missing same-timestamp posts
                let newOnes = try await service.fetchPostsAfter(date: after, perPage: 100)

                if !newOnes.isEmpty {
                    var map = Dictionary(uniqueKeysWithValues: articles.map { ($0.id, $0) })
                    for a in newOnes { map[a.id] = a }
                    self.articles = map.values.sorted(by: { $0.date > $1.date })
                    cache.save(ProspectorCachePayload(articles: self.articles))
                }
            }
        } catch {
            errorText = "Prospector fetch failed: \(error.localizedDescription)"
        }
    }

    private func refreshTaxonomy() async {
        do {
            let cats = try await service.fetchAllCategories(perPage: 100)
            let t = ProspectorTaxonomy(categories: cats)
            self.taxonomy = t
            taxonomyCache.save(t)
        } catch {
            // taxonomy is optional
        }
    }
}



struct ProspectorCachePayload: Codable {
    let articles: [ProspectorArticle]
}

final class ProspectorPostsCache {
    private let cacheURL: URL

    init(filename: String = "prospector_posts_cache.json") {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheURL = dir.appendingPathComponent(filename)
    }

    func load() -> ProspectorCachePayload? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ProspectorCachePayload.self, from: data)
    }

    func save(_ payload: ProspectorCachePayload) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: cacheURL, options: [.atomic])
    }
}



struct WPCategory: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let parent: Int
}

struct ProspectorTaxonomy: Codable {
    let byID: [Int: WPCategory]
    let bySlug: [String: Int]

    init(categories: [WPCategory]) {
        var a: [Int: WPCategory] = [:]
        var b: [String: Int] = [:]
        for c in categories {
            a[c.id] = c
            b[c.slug.lowercased()] = c.id
        }
        self.byID = a
        self.bySlug = b
    }

    func articleHasAnySlug(_ article: ProspectorArticle, slugs: [String]) -> Bool {
        let wanted = Set(slugs.map { $0.lowercased() })

        for id in article.categoryIDs {
            if let c = byID[id] {
                let s = c.slug.lowercased()
                if wanted.contains(s) { return true }

                // check parent
                if c.parent != 0, let p = byID[c.parent], wanted.contains(p.slug.lowercased()) {
                    return true
                }
            }
        }
        return false
    }
}

final class ProspectorTaxonomyCache {
    private let url: URL

    init(filename: String = "prospector_taxonomy_cache.json") {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.url = dir.appendingPathComponent(filename)
    }

    func load() -> ProspectorTaxonomy? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ProspectorTaxonomy.self, from: data)
    }

    func save(_ taxonomy: ProspectorTaxonomy) {
        guard let data = try? JSONEncoder().encode(taxonomy) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}



final class ProspectorNowService {
    private let base = URL(string: "https://prospectornow.com")!

    func fetchAllPosts(perPage: Int = 100) async throws -> [ProspectorArticle] {
        let perPageClamped = max(1, min(perPage, 100))
        var page = 1
        var all: [ProspectorArticle] = []

        while true {
            let chunk = try await fetchPostsPage(page: page, perPage: perPageClamped, afterISO: nil)
            if chunk.isEmpty { break }
            all.append(contentsOf: chunk)
            if chunk.count < perPageClamped { break }
            page += 1
            if page > 500 { break }
        }

        return dedupAndSort(all)
    }

    func fetchPostsAfter(date: Date, perPage: Int = 100) async throws -> [ProspectorArticle] {
        let perPageClamped = max(1, min(perPage, 100))

        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        iso.formatOptions = [.withInternetDateTime]
        let afterISO = iso.string(from: date)

        var page = 1
        var all: [ProspectorArticle] = []

        while true {
            let chunk = try await fetchPostsPage(page: page, perPage: perPageClamped, afterISO: afterISO)
            if chunk.isEmpty { break }
            all.append(contentsOf: chunk)
            if chunk.count < perPageClamped { break }
            page += 1
            if page > 200 { break }
        }

        return dedupAndSort(all)
    }

    func fetchAllCategories(perPage: Int = 100) async throws -> [WPCategory] {
        let perPageClamped = max(1, min(perPage, 100))
        var page = 1
        var all: [WPCategory] = []

        while true {
            let chunk = try await fetchCategoriesPage(page: page, perPage: perPageClamped)
            if chunk.isEmpty { break }
            all.append(contentsOf: chunk)
            if chunk.count < perPageClamped { break }
            page += 1
            if page > 50 { break }
        }

        return all
    }

    private func fetchPostsPage(page: Int, perPage: Int, afterISO: String?) async throws -> [ProspectorArticle] {
        var comps = URLComponents(url: base.appendingPathComponent("/wp-json/wp/v2/posts/"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            .init(name: "page", value: String(page)),
            .init(name: "per_page", value: String(perPage)),
            .init(name: "_embed", value: "1"),
            .init(name: "orderby", value: "date"),
            .init(name: "order", value: "desc")
        ]
        if let afterISO {
            items.append(.init(name: "after", value: afterISO))
        }
        comps.queryItems = items

        var request = URLRequest(url: comps.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.shared.data(for: request)

        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ProspectorNowService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body.prefix(180))"
            ])
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(WPDateDecoder.decode)
        let raw = try decoder.decode([WPPost].self, from: data)
        let mapped = raw.compactMap { $0.toArticle() }
        return mapped
    }

    private func fetchCategoriesPage(page: Int, perPage: Int) async throws -> [WPCategory] {
        var comps = URLComponents(url: base.appendingPathComponent("/wp-json/wp/v2/categories/"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "page", value: String(page)),
            .init(name: "per_page", value: String(perPage)),
            .init(name: "hide_empty", value: "false")
        ]

        var request = URLRequest(url: comps.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await URLSession.shared.data(for: request)

        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "ProspectorNowService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body.prefix(180))"
            ])
        }

        return try JSONDecoder().decode([WPCategory].self, from: data)
    }

    private func dedupAndSort(_ articles: [ProspectorArticle]) -> [ProspectorArticle] {
        var seen = Set<Int>()
        let deduped = articles.filter { a in
            if seen.contains(a.id) { return false }
            seen.insert(a.id)
            return true
        }
        return deduped.sorted(by: { $0.date > $1.date })
    }
}

struct WPPost: Decodable {
    let id: Int
    let date: Date
    let link: String
    let title: Rendered
    let excerpt: Rendered
    let categories: [Int]?
    let embedded: Embedded?

    struct Rendered: Decodable { let rendered: String }

    struct Embedded: Decodable {
        let author: [WPAuthor]?
        let featured: [WPFeaturedMedia]?

        enum CodingKeys: String, CodingKey {
            case author
            case featured = "wp:featuredmedia"
        }
    }

    struct WPAuthor: Decodable { let name: String? }

    struct WPFeaturedMedia: Decodable {
        let sourceURL: String?
        enum CodingKeys: String, CodingKey { case sourceURL = "source_url" }
    }

    enum CodingKeys: String, CodingKey {
        case id, date, link, title, excerpt, categories
        case embedded = "_embedded"
    }

    func toArticle() -> ProspectorArticle? {
        guard let linkURL = URL(string: link) else { return nil }

        let authorName = embedded?.author?.first?.name
        let imgURL = embedded?.featured?.first?.sourceURL.flatMap(URL.init(string:))

        return ProspectorArticle(
            id: id,
            date: date,
            link: linkURL,
            title: title.rendered,
            excerpt: excerpt.rendered,
            authorName: authorName,
            featuredImageURL: imgURL,
            categoryIDs: categories ?? []
        )
    }
}

enum WPDateDecoder {
    static func decode(_ decoder: Decoder) throws -> Date {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = df.date(from: s) { return d }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }

        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }

        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unparseable WP date: \(s)")
    }
}


struct URLItem: Identifiable {
    let id = UUID()
    let url: URL
    init(_ url: URL) { self.url = url }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension ProspectorArticle {
    var titlePlain: String { title }
    var excerptPlain: String { excerpt }
}

//private let htmlPlainCache = NSCache<NSString, NSString>()
//
//private func htmlToPlainTextFast(_ html: String) -> String {
//    if let cached = htmlPlainCache.object(forKey: html as NSString) {
//        return cached as String
//    }
//    if !html.contains("<") && !html.contains("&") { return html }
//
//    var s = html
//    s = s.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
//    s = s.replacingOccurrences(of: "</p\\s*>", with: "\n", options: .regularExpression)
//    s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
//
//    if let decoded = CFXMLCreateStringByUnescapingEntities(nil, s as CFString, nil) {
//        s = decoded as String
//    }
//
//    s = s.replacingOccurrences(of: "[ \t]+\n", with: "\n", options: .regularExpression)
//    s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
//
//    let out = s.trimmingCharacters(in: .whitespacesAndNewlines)
//    htmlPlainCache.setObject(out as NSString, forKey: html as NSString)
//    return out
//}
