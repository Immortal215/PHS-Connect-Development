import SwiftUI

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

    struct Embedded: Decodable { // needed cause normally itll only return author ID so the embedded data needed to find deeper data like the author's actual name
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
            title: title.rendered,
            excerpt: excerpt.rendered,
            date: date,
            link: link,
            authorName: _embedded?.author?.first?.name,
            featuredImageURL: _embedded?.featuredMedia?.first?.source_url
        )
    }
}
