import Foundation
import CoreLocation
import Combine
import SwiftUI

// MARK: - Core Types

struct Coordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

enum CrimeType: String, CaseIterable, Identifiable, Codable {
    case homicide = "Homicidio"
    case assault = "Agresión"
    case robbery = "Robo"
    case harassment = "Acoso"
    case other = "Otro"

    var id: String { rawValue }
}

enum Severity: String, CaseIterable, Identifiable, Codable {
    case low = "Baja"
    case medium = "Media"
    case high = "Alta"
    case critical = "Crítica"

    var id: String { rawValue }
}

struct Report: Identifiable, Codable {
    let id: UUID
    var type: CrimeType
    var severity: Severity
    var description: String
    var address: String
    var date: Date
    var coordinate: Coordinate?
    var likes: Int
    /// Encrypted in Firestore; not displayed in the UI.
    var reportedBy: String?
    /// Decrypted reporter display name — shown in the UI.
    var reportedName: String?
    /// Document status field from Firestore; not displayed in the UI.
    var status: String?
}

struct SavedRoute: Identifiable, Codable {
    let id: UUID
    var name: String
    var originName: String
    var destinationName: String
    var origin: Coordinate
    var destination: Coordinate
    var distanceInKm: Double
    var expectedTravelTimeMinutes: Double
}

struct EmergencyContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var phoneNumber: String
}

struct UserProfile: Identifiable, Codable {
    let id: UUID
    var fullName: String
    var nationalId: String
    var email: String
    var isVerified: Bool
    var emergencyContacts: [EmergencyContact]
}

struct Credentials: Codable {
    var username: String
    var password: String
}

// MARK: - Persistence

/// Tiny wrapper around UserDefaults that reads/writes any Codable value.
/// (Named `LocalStore` to avoid colliding with SwiftUI's `AppStorage` property wrapper.)
enum LocalStore {
    private static let defaults = UserDefaults.standard

    static func save<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    static func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - App-wide State

@MainActor
final class AppData: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var currentUser: UserProfile?
    @Published var credentials: Credentials?
    @Published var reports: [Report]
    @Published var routes: [SavedRoute]
    @Published var likedReportIds: Set<UUID>
    @Published var selectedRouteId: UUID?
    /// Decrypted contents of the Firestore `users` collection (read-only mirror).
    @Published var remoteUsers: [RemoteUser] = []
    /// Decrypted contents of the Firestore `groups` collection (read-only mirror).
    @Published var remoteGroups: [RemoteGroup] = []

    private enum Key {
        static let user = "userProfile"
        static let credentials = "credentials"
        static let reports = "reports"
        static let routes = "routes"
        static let likes = "likedReportIds"
    }

    init() {
        let loadedUser = LocalStore.load(UserProfile.self, forKey: Key.user)
        let loadedCredentials = LocalStore.load(Credentials.self, forKey: Key.credentials)
        self.currentUser = loadedUser
        self.credentials = loadedCredentials
        self.reports = LocalStore.load([Report].self, forKey: Key.reports) ?? []
        self.routes = LocalStore.load([SavedRoute].self, forKey: Key.routes) ?? []
        self.likedReportIds = LocalStore.load(Set<UUID>.self, forKey: Key.likes) ?? []
        self.selectedRouteId = nil
        self.isAuthenticated = loadedUser != nil && loadedCredentials != nil
    }

    // MARK: Auth

    func register(username: String, password: String, fullName: String, nationalId: String, email: String) -> Bool {
        guard !username.isEmpty, !password.isEmpty else { return false }

        let profile = UserProfile(
            id: UUID(),
            fullName: fullName.isEmpty ? username : fullName,
            nationalId: nationalId,
            email: email,
            isVerified: true,
            emergencyContacts: []
        )
        let newCredentials = Credentials(username: username, password: password)

        currentUser = profile
        credentials = newCredentials
        isAuthenticated = true

        LocalStore.save(profile, forKey: Key.user)
        LocalStore.save(newCredentials, forKey: Key.credentials)
        return true
    }

    func login(username: String, password: String) -> Bool {
        guard let stored = credentials,
              stored.username == username,
              stored.password == password,
              currentUser != nil
        else { return false }

        isAuthenticated = true
        return true
    }

    func logout() {
        isAuthenticated = false
    }

    // MARK: Profile

    func updateProfile(_ profile: UserProfile) {
        currentUser = profile
        LocalStore.save(profile, forKey: Key.user)
    }

    func upsertEmergencyContact(_ contact: EmergencyContact) {
        guard var profile = currentUser else { return }
        if let index = profile.emergencyContacts.firstIndex(where: { $0.id == contact.id }) {
            profile.emergencyContacts[index] = contact
        } else {
            profile.emergencyContacts.append(contact)
        }
        updateProfile(profile)
    }

    func removeEmergencyContact(at offsets: IndexSet) {
        guard var profile = currentUser else { return }
        profile.emergencyContacts.remove(atOffsets: offsets)
        updateProfile(profile)
    }

    // MARK: Reports

    func addReport(_ report: Report) {
        reports.insert(report, at: 0)
        LocalStore.save(reports, forKey: Key.reports)
        // Fire-and-forget upload to Firebase. Failures are logged but don't block the UI.
        Task {
            do { try await FirebaseClient.pushReport(report) }
            catch { print("⚠️ Firebase push failed: \(error)") }
        }
    }

    /// Pulls the latest data from all three Firestore collections, decrypts it,
    /// and merges reports with whatever exists locally (local reports keep their
    /// likes; remote-only reports are added on top). Users and groups are
    /// replaced wholesale since they're read-only on the iOS side.
    func refreshFromFirebase() async {
        // Reports
        if let remote = try? await FirebaseClient.fetchReports() {
            var seen = Set<String>()
            func fingerprint(_ r: Report) -> String {
                let lat = r.coordinate?.latitude ?? 0
                let lng = r.coordinate?.longitude ?? 0
                return "\(Int(r.date.timeIntervalSince1970))|\(lat)|\(lng)|\(r.description)"
            }
            var merged: [Report] = []
            for r in reports + remote where !seen.contains(fingerprint(r)) {
                seen.insert(fingerprint(r))
                merged.append(r)
            }
            reports = merged.sorted { $0.date > $1.date }
            LocalStore.save(reports, forKey: Key.reports)
        }

        // Users + groups (decryption is applied inside FirebaseClient).
        if let users = try? await FirebaseClient.fetchUsers() {
            remoteUsers = users
        }
        if let groups = try? await FirebaseClient.fetchGroups() {
            remoteGroups = groups
        }
    }

    /// Toggles a like for the current user. Each user can like a report at most once.
    func toggleLike(for reportId: UUID) {
        guard let index = reports.firstIndex(where: { $0.id == reportId }) else { return }
        if likedReportIds.contains(reportId) {
            likedReportIds.remove(reportId)
            reports[index].likes = max(0, reports[index].likes - 1)
        } else {
            likedReportIds.insert(reportId)
            reports[index].likes += 1
        }
        LocalStore.save(reports, forKey: Key.reports)
        LocalStore.save(likedReportIds, forKey: Key.likes)
    }

    func hasLiked(_ reportId: UUID) -> Bool {
        likedReportIds.contains(reportId)
    }

    // MARK: Routes

    func addRoute(_ route: SavedRoute) {
        routes.append(route)
        LocalStore.save(routes, forKey: Key.routes)
    }

    func removeRoute(at offsets: IndexSet) {
        routes.remove(atOffsets: offsets)
        LocalStore.save(routes, forKey: Key.routes)
    }

    func selectRoute(_ route: SavedRoute?) {
        selectedRouteId = route?.id
    }
}

