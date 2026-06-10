import Foundation

/// Read/write data against Firebase Cloud **Firestore** via its REST API.
///
/// Collections (matching the Android app):
///   • `users`   — user profiles (some fields encrypted with AES-GCM)
///   • `reports` — safety reports (description/address/reportedBy/reportedName encrypted)
///   • `grupos`  — user-created groups (name/description encrypted)
///
/// Decryption flow:
///   Firestore JSON → parse → for every string field, call `EncryptionUtils.decrypt(...)`.
///   `decrypt()` returns the original string when it's not an AES-GCM blob, so this
///   pass-through is safe for fields that were never encrypted.
enum FirebaseClient {

    private static let projectId = FirebaseConfig.projectId
    private static let apiKey    = FirebaseConfig.apiKey
    private static var baseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents"
    }

    // MARK: - Public API

    static func fetchReports() async throws -> [Report] {
        let docs = try await fetchCollection(name: "reports")
        return docs.compactMap(reportFromDocument).sorted { $0.date > $1.date }
    }

    static func fetchUsers() async throws -> [RemoteUser] {
        let docs = try await fetchCollection(name: "users")
        return docs.compactMap(userFromDocument)
    }

    static func fetchGroups() async throws -> [RemoteGroup] {
        let docs = try await fetchCollection(name: "grupos")
        return docs.compactMap(groupFromDocument)
    }

    /// Writes a new encrypted report to Firestore under the `reports` collection.
    static func pushReport(_ report: Report) async throws {
        let url = URL(string: "\(baseURL)/reports?key=\(apiKey)")!

        var fields: [String: Any] = [
            "type":        ["stringValue": report.type.rawValue],
            "severity":    ["stringValue": report.severity.rawValue],
            "description": ["stringValue": EncryptionUtils.encrypt(report.description)],
            "address":     ["stringValue": EncryptionUtils.encrypt(report.address)],
            "timestamp":   ["timestampValue": iso8601.string(from: report.date)],
            "status":      ["stringValue": report.status ?? "active"],
            "likes":       ["integerValue": String(report.likes)],
        ]

        // Encrypted reporter identity
        if let reportedBy = report.reportedBy, !reportedBy.isEmpty {
            fields["reportedBy"] = ["stringValue": EncryptionUtils.encrypt(reportedBy)]
        }
        if let reportedName = report.reportedName, !reportedName.isEmpty {
            fields["reportedName"] = ["stringValue": EncryptionUtils.encrypt(reportedName)]
        }

        // Location stored as a Firestore mapValue with lat/lng sub-fields
        if let c = report.coordinate {
            fields["location"] = [
                "mapValue": [
                    "fields": [
                        "latitude":  ["doubleValue": c.latitude],
                        "longitude": ["doubleValue": c.longitude]
                    ]
                ]
            ]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["fields": fields])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Generic collection fetch

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Returns the raw `fields` dictionary of each document, after recursively
    /// running every string value through `EncryptionUtils.decrypt`.
    private static func fetchCollection(name: String) async throws -> [[String: Any]] {
        let url = URL(string: "\(baseURL)/\(name)?key=\(apiKey)&pageSize=300")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            return []
        }
        return documents.compactMap { doc -> [String: Any]? in
            guard let fields = doc["fields"] as? [String: Any] else { return nil }
            return decryptFields(fields)
        }
    }

    /// Walks the Firestore `fields` dictionary and:
    ///   • Unwraps Firestore type wrappers (stringValue / doubleValue / timestampValue / geoPointValue / …)
    ///   • Decrypts every `stringValue` via `EncryptionUtils.decrypt`
    private static func decryptFields(_ fields: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, raw) in fields {
            guard let wrapper = raw as? [String: Any] else { continue }
            if let s = wrapper["stringValue"] as? String {
                out[key] = EncryptionUtils.decrypt(s)
            } else if let n = wrapper["doubleValue"] as? Double {
                out[key] = n
            } else if let n = wrapper["integerValue"] as? String, let i = Int(n) {
                out[key] = i
            } else if let n = wrapper["integerValue"] as? Int {
                out[key] = n
            } else if let b = wrapper["booleanValue"] as? Bool {
                out[key] = b
            } else if let ts = wrapper["timestampValue"] as? String {
                // Keep as ISO8601 string; parsed in mappers
                out[key] = ts
            } else if let gp = wrapper["geoPointValue"] as? [String: Any] {
                // Firestore GeoPoint → plain dictionary
                out[key] = gp
            } else if let map = wrapper["mapValue"] as? [String: Any],
                      let inner = map["fields"] as? [String: Any] {
                out[key] = decryptFields(inner)
            } else if let arr = wrapper["arrayValue"] as? [String: Any],
                      let values = arr["values"] as? [[String: Any]] {
                out[key] = values.compactMap { v -> Any? in
                    if let s = v["stringValue"] as? String { return EncryptionUtils.decrypt(s) }
                    if let d = v["doubleValue"]  as? Double { return d }
                    if let i = v["integerValue"] as? String { return Int(i) ?? i }
                    return nil
                }
            }
        }
        return out
    }

    // MARK: - Mappers

    private static func reportFromDocument(_ f: [String: Any]) -> Report? {
        guard let typeRaw = f["type"] as? String, let type = CrimeType(rawValue: typeRaw),
              let sevRaw  = f["severity"] as? String, let severity = Severity(rawValue: sevRaw)
        else { return nil }

        // Location: prefer `location` mapValue/geoPoint, fall back to flat lat/lng (legacy iOS writes)
        let coordinate: Coordinate? = {
            if let loc = f["location"] as? [String: Any],
               let lat = loc["latitude"]  as? Double,
               let lng = loc["longitude"] as? Double {
                return Coordinate(latitude: lat, longitude: lng)
            }
            if let lat = f["latitude"] as? Double, let lng = f["longitude"] as? Double {
                return Coordinate(latitude: lat, longitude: lng)
            }
            return nil
        }()

        // Date: prefer `timestamp` (Android convention), fall back to `date` (legacy iOS)
        let date: Date = {
            let withFrac = iso8601
            let simple   = ISO8601DateFormatter()
            for key in ["timestamp", "date"] {
                if let s = f[key] as? String {
                    if let d = withFrac.date(from: s) { return d }
                    if let d = simple.date(from: s)   { return d }
                }
            }
            return Date()
        }()

        return Report(
            id: UUID(),
            type: type,
            severity: severity,
            description: (f["description"] as? String) ?? "",
            address:     (f["address"]     as? String) ?? "",
            date: date,
            coordinate: coordinate,
            likes: (f["likes"] as? Int) ?? 0,
            reportedBy:   f["reportedBy"]   as? String,
            reportedName: f["reportedName"] as? String,
            status:       f["status"]       as? String
        )
    }

    private static func userFromDocument(_ f: [String: Any]) -> RemoteUser? {
        guard let email = f["email"] as? String else { return nil }
        return RemoteUser(
            email: email,
            fullName: (f["fullName"] as? String) ?? (f["name"] as? String) ?? "",
            nationalId: (f["nationalId"] as? String) ?? "",
            phoneNumber: (f["phoneNumber"] as? String) ?? (f["phone"] as? String) ?? ""
        )
    }

    private static func groupFromDocument(_ f: [String: Any]) -> RemoteGroup? {
        guard let name = f["name"] as? String else { return nil }
        return RemoteGroup(
            name: name,
            description: (f["description"] as? String) ?? "",
            memberEmails: (f["members"] as? [Any])?.compactMap { $0 as? String } ?? []
        )
    }
}

// MARK: - Lightweight DTOs for the other two collections

struct RemoteUser: Identifiable, Equatable {
    var id: String { email }
    let email: String
    let fullName: String
    let nationalId: String
    let phoneNumber: String
}

struct RemoteGroup: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let description: String
    let memberEmails: [String]
}
