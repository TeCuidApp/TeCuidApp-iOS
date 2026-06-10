import SwiftUI
import CoreLocation

struct ReportsView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var locationManager: LocationManager
    @State private var isPresentingNewReport = false

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)
    private let darkCard = Color(red: 0.11, green: 0.11, blue: 0.13)

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color(red: 0.04, green: 0.04, blue: 0.06)
                    .ignoresSafeArea()

                if appData.reports.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.fill")
                            .font(.system(size: 40))
                            .foregroundColor(primaryPink)
                        Text("No hay reportes aún")
                            .foregroundColor(.white)
                            .font(.headline)
                        Text("Comparte información de seguridad en tu zona para ayudar a otras personas.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(appData.reports) { report in
                                ReportCard(
                                    report: report,
                                    isLiked: appData.hasLiked(report.id),
                                    primaryPink: primaryPink,
                                    darkCard: darkCard
                                ) {
                                    appData.toggleLike(for: report.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                Button {
                    isPresentingNewReport = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(primaryPink)
                        .clipShape(Circle())
                        .shadow(radius: 8)
                        .padding()
                }
            }
            .navigationTitle("Reportes de seguridad")
        }
        .sheet(isPresented: $isPresentingNewReport) {
            NewReportView(isPresented: $isPresentingNewReport)
                .environmentObject(appData)
                .environmentObject(locationManager)
        }
    }
}

private struct ReportCard: View {
    let report: Report
    let isLiked: Bool
    let primaryPink: Color
    let darkCard: Color
    let onLike: () -> Void

    private var severityColor: Color {
        switch report.severity {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(severityColor)
                    Text(report.type.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()

                Text(report.severity.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(severityColor.opacity(0.2))
                    .foregroundColor(severityColor)
                    .clipShape(Capsule())
            }

            Text(report.description)
                .foregroundColor(.white)
                .font(.subheadline)

            Text(report.address)
                .foregroundColor(.gray)
                .font(.footnote)

            if let name = report.reportedName, !name.isEmpty {
                Text("Reportado por: \(name)")
                    .foregroundColor(.gray)
                    .font(.footnote)
                    .italic()
            }

            Text(report.date, style: .date)
                .foregroundColor(.gray)
                .font(.footnote)

            HStack {
                Spacer()
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                        Text("\(report.likes)")
                    }
                    .font(.footnote)
                    .foregroundColor(primaryPink)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(darkCard)
        .cornerRadius(16)
    }
}

struct NewReportView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var locationManager: LocationManager
    @Binding var isPresented: Bool

    @State private var selectedType: CrimeType = .harassment
    @State private var selectedSeverity: Severity = .medium
    @State private var descriptionText: String = ""
    @State private var address: String = ""
    @State private var date: Date = Date()
    @State private var useCurrentLocation: Bool = true
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tipo de incidente")) {
                    Picker("Tipo", selection: $selectedType) {
                        ForEach(CrimeType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    Picker("Severidad", selection: $selectedSeverity) {
                        ForEach(Severity.allCases) { severity in
                            Text(severity.rawValue).tag(severity)
                        }
                    }
                }

                Section(header: Text("Detalles")) {
                    TextField("Descripción breve", text: $descriptionText, axis: .vertical)
                    DatePicker("Fecha y hora", selection: $date)
                }

                Section(header: Text("Ubicación")) {
                    Toggle("Usar mi ubicación actual", isOn: $useCurrentLocation)
                        .onChange(of: useCurrentLocation) { _, newValue in
                            if newValue { locationManager.startUpdating() }
                        }

                    if useCurrentLocation {
                        if let location = locationManager.currentLocation {
                            Text("Lat: \(location.coordinate.latitude, specifier: "%.4f"), Lng: \(location.coordinate.longitude, specifier: "%.4f")")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Obteniendo ubicación...")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        TextField("Dirección o referencia", text: $address)
                        Text("Buscaremos la ubicación a partir de la dirección.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Nuevo reporte")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar") { saveReport() }
                            .disabled(!canSave)
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        guard !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if !useCurrentLocation {
            return !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func saveReport() {
        errorMessage = nil

        if useCurrentLocation {
            let coord = locationManager.currentLocation.map { Coordinate($0.coordinate) }
            let resolvedAddress = address.isEmpty ? "Mi ubicación" : address
            persist(coordinate: coord, address: resolvedAddress)
            return
        }

        // Address-based: ask Google Geocoding so the report appears on the map.
        isSaving = true
        let typedAddress = address
        Task {
            do {
                let coord = try await GeocodingAPI.coordinate(for: typedAddress)
                await MainActor.run {
                    self.isSaving = false
                    guard let coord else {
                        self.errorMessage = "No pudimos encontrar esa dirección. Intenta ser más específico."
                        return
                    }
                    self.persist(coordinate: Coordinate(coord), address: typedAddress)
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = "Error de red. Verifica tu conexión."
                }
            }
        }
    }

    private func persist(coordinate: Coordinate?, address: String) {
        let report = Report(
            id: UUID(),
            type: selectedType,
            severity: selectedSeverity,
            description: descriptionText,
            address: address,
            date: date,
            coordinate: coordinate,
            likes: 0,
            reportedBy: appData.currentUser?.id.uuidString,
            reportedName: appData.currentUser?.fullName,
            status: "active"
        )
        appData.addReport(report)
        isPresented = false
    }
}

