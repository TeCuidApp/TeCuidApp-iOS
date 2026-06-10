import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appData: AppData
    @State private var isEditing = false
    @State private var editedProfile: UserProfile?
    @State private var showAddContact = false

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)
    private let lightPink = Color(red: 1.0, green: 0.93, blue: 0.96)

    var body: some View {
        NavigationView {
            ZStack {
                lightPink.ignoresSafeArea()

                if let user = appData.currentUser {
                    ScrollView {
                        VStack(spacing: 24) {
                            profileHeader(user: user)

                            profileInfoSection(user: user)

                            emergencyContactsSection(user: user)

                            logoutButton()
                        }
                        .padding(.vertical, 20)
                    }
                } else {
                    Text("No hay perfil de usuario")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Perfil")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isEditing = true
                        editedProfile = appData.currentUser
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(primaryPink)
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditProfileView(profile: $editedProfile, isPresented: $isEditing)
                    .environmentObject(appData)
            }
            .sheet(isPresented: $showAddContact) {
                AddEmergencyContactView(isPresented: $showAddContact)
                    .environmentObject(appData)
            }
        }
    }

    @ViewBuilder
    private func profileHeader(user: UserProfile) -> some View {
        VStack(spacing: 12) {
            Circle()
                .fill(primaryPink)
                .frame(width: 100, height: 100)
                .overlay(
                    Text(String(user.fullName.prefix(1)).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                )

            Text(user.fullName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            if user.isVerified {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Verificada")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 8)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func profileInfoSection(user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Información del Perfil")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                InfoRow(icon: "person.fill", title: "Nombre Completo", value: user.fullName, color: primaryPink)
                InfoRow(icon: "person.text.rectangle.fill", title: "Cédula", value: user.nationalId, color: primaryPink)
                InfoRow(icon: "envelope.fill", title: "Correo Electrónico", value: user.email, color: primaryPink)
            }
            .padding()
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 8)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func emergencyContactsSection(user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Contactos de Emergencia")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    showAddContact = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(primaryPink)
                }
            }
            .padding(.horizontal, 20)

            if user.emergencyContacts.isEmpty {
                Text("No hay contactos de emergencia. Agrega al menos uno.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            } else {
                ForEach(user.emergencyContacts) { contact in
                    EmergencyContactInfoRow(contact: contact, primaryPink: primaryPink)
                }
            }
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 8)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func logoutButton() -> some View {
        Button {
            appData.logout()
        } label: {
            Text("Cerrar Sesión")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
        }
        .padding(.horizontal, 24)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }
}

struct EmergencyContactInfoRow: View {
    let contact: EmergencyContact
    let primaryPink: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(primaryPink)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(contact.phoneNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                if let url = URL(string: "tel://\(contact.phoneNumber.replacingOccurrences(of: " ", with: ""))") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Image(systemName: "phone.fill")
                    .foregroundColor(primaryPink)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var appData: AppData
    @Binding var profile: UserProfile?
    @Binding var isPresented: Bool

    @State private var fullName: String = ""
    @State private var nationalId: String = ""
    @State private var email: String = ""

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Información Personal")) {
                    TextField("Nombre Completo", text: $fullName)
                    TextField("Cédula", text: $nationalId)
                    TextField("Correo Electrónico", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Editar Perfil")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveProfile()
                    }
                }
            }
            .onAppear {
                if let p = profile {
                    fullName = p.fullName
                    nationalId = p.nationalId
                    email = p.email
                }
            }
        }
    }

    private func saveProfile() {
        guard var updated = profile else { return }
        updated.fullName = fullName
        updated.nationalId = nationalId
        updated.email = email
        appData.updateProfile(updated)
        isPresented = false
    }
}

struct AddEmergencyContactView: View {
    @EnvironmentObject private var appData: AppData
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var phoneNumber: String = ""

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nuevo Contacto")) {
                    TextField("Nombre", text: $name)
                    TextField("Teléfono", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Agregar Contacto")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveContact()
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }

    private func saveContact() {
        let contact = EmergencyContact(
            id: UUID(),
            name: name,
            phoneNumber: phoneNumber
        )
        appData.upsertEmergencyContact(contact)
        isPresented = false
    }
}
