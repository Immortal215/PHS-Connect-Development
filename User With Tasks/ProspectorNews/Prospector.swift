import SwiftUI
import SafariServices
import SDWebImageSwiftUI

struct ProspectorView: View {
    @StateObject var vm = ProspectorViewModel()
    @State var openURL: URL?

    var body: some View {
        NavigationStack {
            List {
                if let err = vm.errorText {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                ForEach(vm.articles) { article in
                    Button {
                        openURL = article.link
                    } label: {
                        ArticleRow(article: article)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task { await vm.loadMoreIfNeeded(current: article) }
                    }
                }

                if vm.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            }
            .listStyle(.plain)
            .navigationTitle("ProspectorNow")
            .refreshable { await vm.refresh() }
            .task { if vm.articles.isEmpty { await vm.refresh() } }
            .fullScreenCover(item: Binding(
                get: { openURL.map(URLItem.init) }, // purely just to make URL identifiable
                set: { openURL = $0?.url }
            )) { item in
                SafariView(url: item.url).ignoresSafeArea()
                
            }
        }
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
                Text(article.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !article.excerpt.isEmpty {
                    Text(article.excerpt)
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
        }
    }
}

@MainActor
final class ProspectorViewModel: ObservableObject {
    @Published var articles: [ProspectorArticle] = []
    @Published var isLoading = false
    @Published var errorText: String? = nil

    let service = ProspectorNowService()
    var page = 1
    var reachedEnd = false

    func refresh() async {
        page = 1
        reachedEnd = false
        articles.removeAll()
        errorText = nil
        await loadMoreIfNeeded(current: nil)
    }

    func loadMoreIfNeeded(current: ProspectorArticle?) async {
        guard !isLoading, !reachedEnd else { return }
        if let current, current.id != articles.last?.id { return }

        isLoading = true
        do {
            let new = try await service.fetchPosts(page: page, perPage: 20)
            if new.isEmpty { reachedEnd = true }
            for a in new where !articles.contains(where: { $0.id == a.id }) {
                articles.append(a)
            }
            page += 1
        } catch {
            errorText = "Prospector fetch failed: \(error.localizedDescription)"
            reachedEnd = true
        }
        isLoading = false
    }
}


final class ProspectorNowService {
    let base = URL(string: "https://prospectornow.com")!

    func fetchPosts(page: Int, perPage: Int) async throws -> [ProspectorArticle] {
        var comps = URLComponents(url: base.appendingPathComponent("/wp-json/wp/v2/posts/"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "page", value: String(page)),
            .init(name: "per_page", value: String(perPage)),
            .init(name: "_embed", value: "1")
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

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(WPDateDecoder.decode)
        let raw = try decoder.decode([WPPost].self, from: data)
        return raw.map { $0.toArticle() }
    }
}

struct ProspectorArticle: Identifiable, Equatable {
    let id: Int
    let title: String
    let excerpt: String
    let date: Date
    let link: URL
    let authorName: String?
    let featuredImageURL: URL?
}

struct WPPost: Decodable { // A lot are structs becuase they are returned as objects not strings by wordpress so it needs to be like this
    struct Rendered: Decodable { let rendered: String }

    let id: Int
    let date: Date
    let link: URL
    let title: Rendered
    let excerpt: Rendered
    let _embedded: Embedded?

    struct Embedded: Decodable { // needed cause normally itll only return author ID so the embedded data needed to be found deeper
        let author: [Author]?
        let featuredMedia: [FeaturedMedia]?

        enum CodingKeys: String, CodingKey {
            case author
            case featuredMedia = "wp:featuredmedia"
        }

        struct Author: Decodable { let name: String? }
        struct FeaturedMedia: Decodable { let source_url: URL? }
    }

    func toArticle() -> ProspectorArticle {
        ProspectorArticle(
            id: id,
            title: title.rendered.cleanHTML(),
            excerpt: excerpt.rendered.cleanHTML(),
            date: date,
            link: link,
            authorName: _embedded?.author?.first?.name,
            featuredImageURL: _embedded?.featuredMedia?.first?.source_url
        )
    }
}

enum WPDateDecoder {
    static func decode(_ decoder: Decoder) throws -> Date {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)

        // 1) WordPress often: 2025-12-18T14:05:12 (no timezone)
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = df.date(from: s) { return d }

        // 2) With timezone: 2025-12-18T14:05:12Z or with offset
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }

        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }

        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unparseable WP date: \(s)")
    }
}

extension String {
    func cleanHTML() -> String {
        self
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#8217;", with: "’")
            .replacingOccurrences(of: "&#8220;", with: "“")
            .replacingOccurrences(of: "&#8221;", with: "”")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
