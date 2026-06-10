import SwiftUI
import CoreLocation

struct MapScreen: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var locationManager: LocationManager
    @State private var showHeatmap = false
    @State private var routePolyline: String?

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)

    var body: some View {
        NavigationView {
            ZStack(alignment: .topTrailing) {
                GoogleMapsView(
                    reports: appData.reports,
                    selectedRoutePolyline: routePolyline,
                    userLocation: locationManager.currentLocation?.coordinate,
                    showHeatmap: showHeatmap
                )
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 12) {
                    if locationManager.authorizationStatus == .authorizedWhenInUse
                        || locationManager.authorizationStatus == .authorizedAlways {
                        HStack {
                            Image(systemName: "location.fill").foregroundColor(.green)
                            Text("Ubicación activada").font(.caption).foregroundColor(.green)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                        .padding(.top, 8)
                    }

                    Button {
                        showHeatmap.toggle()
                    } label: {
                        HStack {
                            Image(systemName: showHeatmap ? "map.fill" : "flame.fill")
                            Text(showHeatmap ? "Ocultar mapa de calor" : "Mapa de calor")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(showHeatmap ? Color.green : primaryPink)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                    }
                    .padding(.trailing, 16)
                }
            }
            .navigationTitle("Mapa")
        }
        .onAppear {
            locationManager.startUpdating()
            Task { await appData.refreshFromFirebase() }
            Task { await loadSelectedRoutePolyline() }
        }
        .onChange(of: appData.selectedRouteId) { _, _ in
            Task { await loadSelectedRoutePolyline() }
        }
    }

    /// Asks Google Directions for the walking polyline of the currently-selected saved route.
    private func loadSelectedRoutePolyline() async {
        guard let routeId = appData.selectedRouteId,
              let route = appData.routes.first(where: { $0.id == routeId }) else {
            routePolyline = nil
            return
        }
        do {
            let result = try await DirectionsAPI.walkingRoute(
                from: route.origin.clLocationCoordinate,
                to: route.destination.clLocationCoordinate
            )
            routePolyline = result.encodedPolyline.isEmpty ? nil : result.encodedPolyline
        } catch {
            routePolyline = nil
        }
    }
}
