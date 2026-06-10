import Foundation
import CoreLocation

/// API key for all Google Maps Platform calls:
/// Places API, Directions API, Maps SDK, and Geolocation API.
enum GoogleMaps {
    static let apiKey = "AIzaSyBNOItTjAxhVybpkWfYwyvDhOOvrEtzd7s"
}

/// Firebase project configuration for Firestore REST calls.
/// Values sourced from GoogleService-Info.plist (iOS client).
enum FirebaseConfig {
    static let projectId = "tecuidapp-c2636"
    static let apiKey    = "AIzaSyA3FFGt2aqqaoSYwsVQNbx0UUo7YiuBfZs"
}

// MARK: - Directions API

enum DirectionsAPI {
    struct Result {
        let distanceKm: Double
        let durationMinutes: Double
        /// Encoded polyline. Pass directly to Google Maps JS via `google.maps.geometry.encoding.decodePath`.
        let encodedPolyline: String
    }

    /// Walking route from origin → destination using Google Directions REST.
    static func walkingRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> Result {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")!
        components.queryItems = [
            .init(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            .init(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            .init(name: "mode", value: "walking"),
            .init(name: "key", value: GoogleMaps.apiKey),
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(DirectionsResponse.self, from: data)

        guard let leg = decoded.routes.first?.legs.first,
              let polyline = decoded.routes.first?.overview_polyline.points else {
            // Fallback: straight-line.
            let km = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude)) / 1000.0
            return Result(distanceKm: km, durationMinutes: km * 12.0, encodedPolyline: "")
        }
        return Result(
            distanceKm: Double(leg.distance.value) / 1000.0,
            durationMinutes: Double(leg.duration.value) / 60.0,
            encodedPolyline: polyline
        )
    }

    // Minimal subset of the Directions response we actually consume.
    private struct DirectionsResponse: Decodable {
        let routes: [Route]
        struct Route: Decodable {
            let legs: [Leg]
            let overview_polyline: Polyline
        }
        struct Leg: Decodable {
            let distance: ValueText
            let duration: ValueText
        }
        struct ValueText: Decodable { let value: Int }
        struct Polyline: Decodable { let points: String }
    }
}

// MARK: - Geocoding API

enum GeocodingAPI {
    /// Forward-geocode a human-readable address → coordinate.
    /// Uses Google's Geocoding REST so it behaves identically to the Android app.
    static func coordinate(for address: String) async throws -> CLLocationCoordinate2D? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")!
        components.queryItems = [
            .init(name: "address", value: trimmed),
            .init(name: "key", value: GoogleMaps.apiKey),
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(GeocodeResponse.self, from: data)
        guard let location = decoded.results.first?.geometry.location else { return nil }
        return CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng)
    }

    private struct GeocodeResponse: Decodable {
        let results: [Result]
        struct Result: Decodable { let geometry: Geometry }
        struct Geometry: Decodable { let location: LatLng }
        struct LatLng: Decodable { let lat: Double; let lng: Double }
    }
}
