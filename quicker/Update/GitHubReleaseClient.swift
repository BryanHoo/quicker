import Foundation

enum GitHubReleaseClientError: Error {
    case invalidResponse
    case httpStatus(Int, Data)
}

struct GitHubReleaseClient {
    var session: URLSession = .shared
    var owner: String = "BryanHoo"
    var repo: String = "quicker"

    func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("quicker", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubReleaseClientError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GitHubReleaseClientError.httpStatus(http.statusCode, data) }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
}
