import SwiftUI

struct SOSView: View {
    @EnvironmentObject private var appData: AppData
    @State private var isCalling = false
    @State private var showEmergencyContacts = false

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)
    private let emergencyRed = Color(red: 0.86, green: 0.08, blue: 0.24)
    private let lightPink = Color(red: 1.0, green: 0.93, blue: 0.96)

    var body: some View {
        NavigationView {
            ZStack {
                lightPink.ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(emergencyRed)
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())

                        Text("Centro de Emergencias")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(emergencyRed)

                        Text("Presiona el botón SOS para llamar inmediatamente al 123")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 8)
                    .padding(.horizontal, 24)
                    .padding(.top, 40)

                    Button {
                        callEmergency()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 40))
                            Text("SOS")
                                .font(.system(size: 32, weight: .bold))
                            Text("EMERGENCIA")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(width: 180, height: 180)
                        .background(emergencyRed)
                        .clipShape(Circle())
                        .shadow(radius: 12)
                        .scaleEffect(isCalling ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: isCalling)
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.1)
                            .onEnded { _ in
                                callEmergency()
                            }
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contactos de Emergencia")
                            .font(.headline)
                            .foregroundColor(emergencyRed)
                            .padding(.horizontal, 20)

                        ScrollView {
                            VStack(spacing: 12) {
                                EmergencyContactRow(
                                    name: "Policía Nacional",
                                    phone: "123",
                                    icon: "shield.fill",
                                    isOfficial: true
                                ) {
                                    callNumber("123")
                                }

                                if let user = appData.currentUser {
                                    ForEach(user.emergencyContacts.prefix(2)) { contact in
                                        EmergencyContactRow(
                                            name: contact.name,
                                            phone: contact.phoneNumber,
                                            icon: "person.fill",
                                            isOfficial: false
                                        ) {
                                            callNumber(contact.phoneNumber)
                                        }
                                    }
                                }

                                if appData.currentUser?.emergencyContacts.count ?? 0 < 2 {
                                    Button {
                                        showEmergencyContacts = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Agregar contacto de emergencia")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(primaryPink)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 8)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle("SOS")
        }
        .sheet(isPresented: $showEmergencyContacts) {
            NavigationView {
                ProfileView()
                    .environmentObject(appData)
            }
        }
    }

    private func callEmergency() {
        isCalling = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            callNumber("123")
            isCalling = false
        }
    }

    private func callNumber(_ number: String) {
        let cleaned = number.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}

struct EmergencyContactRow: View {
    let name: String
    let phone: String
    let icon: String
    let isOfficial: Bool
    let action: () -> Void

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(isOfficial ? Color.red : primaryPink)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(phone)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "phone.fill")
                    .foregroundColor(primaryPink)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}
