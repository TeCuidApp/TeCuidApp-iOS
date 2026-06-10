import SwiftUI

private enum Tab: Hashable {
    case reports
    case map
    case sos
    case routes
    case profile
}

struct MainTabView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var locationManager: LocationManager
    @State private var selectedTab: Tab = .map

    private let accent = Color(red: 0.95, green: 0.16, blue: 0.49)

    var body: some View {
        TabView(selection: $selectedTab) {
            ReportsView()
                .tabItem {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Reportes")
                }
                .tag(Tab.reports)

            MapScreen()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Mapa")
                }
                .tag(Tab.map)

            SOSView()
                .tabItem {
                    Image(systemName: "phone.fill")
                    Text("SOS")
                }
                .tag(Tab.sos)

            RoutesView()
                .tabItem {
                    Image(systemName: "figure.walk")
                    Text("Rutas")
                }
                .tag(Tab.routes)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Perfil")
                }
                .tag(Tab.profile)
        }
        .tint(accent)
        .onAppear {
            locationManager.startUpdating()
            Task { await appData.refreshFromFirebase() }
        }
    }
}

