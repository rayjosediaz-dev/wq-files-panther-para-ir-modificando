import Foundation

struct PantherPatch: Decodable, Identifiable {
    let id: String
    let name: String
    let category: String?
}

struct PantherActivation: Decodable {
    let token: String
}

struct PantherCatalog: Decodable {
    let patches: [PantherPatch]
}

final class PantherAPI {
    static let shared = PantherAPI()
    let baseURL = URL(string: "https://panther-servidor.onrender.com")!
    private(set) var token: String?

    func activate(key: String, deviceID: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/activate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["key": key, "device_id": deviceID])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        token = try JSONDecoder().decode(PantherActivation.self, from: data).token
    }

    func catalog() async throws -> [PantherPatch] {
        let (data, _) = try await authorizedRequest(path: "v1/patches")
        return try JSONDecoder().decode(PantherCatalog.self, from: data).patches
    }

    func download(patchID: String) async throws -> URL {
        guard !patchID.isEmpty, patchID.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            throw URLError(.badURL)
        }
        let (data, _) = try await authorizedRequest(path: "v1/patches/\\(patchID)/download")
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PantherPatches", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(patchID + ".3105")
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func logout() { token = nil }

    private func authorizedRequest(path: String) async throws -> (Data, URLResponse) {
        guard let token else { throw URLError(.userAuthenticationRequired) }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let result = try await URLSession.shared.data(for: request)
        try validate(result.1)
        return result
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
