import SwiftUI
import CoreLocation

struct RoutesView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var locationManager: LocationManager
    @State private var isPresentingNewRoute = false
    @State private var selectedRoute: SavedRoute?

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)
    private let lightPink = Color(red: 1.0, green: 0.93, blue: 0.96)

    var body: some View {
        NavigationView {
            ZStack {
                lightPink.ignoresSafeArea()

                if appData.routes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 50))
                            .foregroundColor(primaryPink)
                        Text("No hay rutas guardadas")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Guarda tus rutas más frecuentes para acceso rápido")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(appData.routes) { route in
                            RouteCard(route: route, primaryPink: primaryPink) {
                                selectedRoute = route
                                appData.selectRoute(route)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteRoutes)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Rutas")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingNewRoute = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(primaryPink)
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewRoute) {
                NewRouteView(isPresented: $isPresentingNewRoute)
                    .environmentObject(appData)
                    .environmentObject(locationManager)
            }
        }
    }

    private func deleteRoutes(at offsets: IndexSet) {
        appData.removeRoute(at: offsets)
    }
}

struct RouteCard: View {
    let route: SavedRoute
    let primaryPink: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(route.originName) → \(route.destinationName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(primaryPink)
                }

                HStack(spacing: 20) {
                    Label("\(route.distanceInKm, specifier: "%.1f") km", systemImage: "ruler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("\(Int(route.expectedTravelTimeMinutes)) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 4)
        }
        .buttonStyle(.plain)
    }
}

struct NewRouteView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var locationManager: LocationManager
    @Binding var isPresented: Bool

    @State private var routeName: String = ""
    @State private var originName: String = ""
    @State private var destinationName: String = ""
    @State private var useCurrentLocation: Bool = true
    @State private var isCalculating: Bool = false

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Información de la ruta")) {
                    TextField("Nombre de la ruta", text: $routeName)
                }

                Section(header: Text("Origen")) {
                    Toggle("Usar mi ubicación actual", isOn: $useCurrentLocation)
                    if !useCurrentLocation {
                        TextField("Dirección de origen", text: $originName)
                    } else {
                        Text(locationManager.currentLocation != nil
                             ? "Ubicación actual detectada"
                             : "Obteniendo ubicación...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Destino")) {
                    TextField("Dirección de destino", text: $destinationName)
                }

                Section {
                    Button {
                        calculateAndSaveRoute()
                    } label: {
                        HStack {
                            Spacer()
                            if isCalculating {
                                ProgressView()
                            } else {
                                Text("Guardar ruta")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(primaryPink)
                        .cornerRadius(12)
                    }
                    .disabled(routeName.isEmpty || destinationName.isEmpty || isCalculating)
                }
            }
            .navigationTitle("Nueva ruta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func calculateAndSaveRoute() {
        guard !routeName.isEmpty, !destinationName.isEmpty else { return }
        isCalculating = true

        Task {
            let result = await buildRoute()
            await MainActor.run {
                self.isCalculating = false
                if let result {
                    self.appData.addRoute(result)
                    self.isPresented = false
                }
            }
        }
    }

    /// Resolves origin + destination addresses via Google Geocoding and computes
    /// the walking route via Google Directions. Returns nil if anything fails.
    private func buildRoute() async -> SavedRoute? {
        // Origin
        let originCoord: CLLocationCoordinate2D
        let resolvedOriginName: String
        if useCurrentLocation, let current = locationManager.currentLocation {
            originCoord = current.coordinate
            resolvedOriginName = originName.isEmpty ? "Mi ubicación" : originName
        } else {
            guard let coord = try? await GeocodingAPI.coordinate(for: originName) else { return nil }
            originCoord = coord
            resolvedOriginName = originName
        }

        // Destination
        guard let destCoord = try? await GeocodingAPI.coordinate(for: destinationName) else { return nil }

        // Directions (falls back to straight-line internally on failure).
        let directions = (try? await DirectionsAPI.walkingRoute(from: originCoord, to: destCoord))
            ?? DirectionsAPI.Result(
                distanceKm: CLLocation(latitude: originCoord.latitude, longitude: originCoord.longitude)
                    .distance(from: CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude)) / 1000.0,
                durationMinutes: 0,
                encodedPolyline: ""
            )

        return SavedRoute(
            id: UUID(),
            name: routeName,
            originName: resolvedOriginName,
            destinationName: destinationName,
            origin: Coordinate(originCoord),
            destination: Coordinate(destCoord),
            distanceInKm: directions.distanceKm,
            expectedTravelTimeMinutes: directions.durationMinutes
        )
    }
}
