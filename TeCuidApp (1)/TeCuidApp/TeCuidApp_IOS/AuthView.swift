import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var locationManager: LocationManager

    @State private var isLoginMode: Bool = true

    @State private var username: String = ""
    @State private var password: String = ""

    @State private var fullName: String = ""
    @State private var nationalId: String = ""
    @State private var email: String = ""

    @State private var errorMessage: String?

    private let primaryPink = Color(red: 0.95, green: 0.16, blue: 0.49)
    private let lightBackground = Color(red: 1.0, green: 0.93, blue: 0.96)

    var body: some View {
        ZStack {
            lightBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Circle()
                        .fill(primaryPink)
                        .frame(width: 96, height: 96)
                        .overlay(
                            Image(systemName: "shield.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white)
                                .padding(24)
                        )

                    Text("TeCuidApp")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(primaryPink)

                    Text("Tu compañera de confianza para viajes seguros")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        authModeButton(title: "Iniciar Sesión", isSelected: isLoginMode) {
                            isLoginMode = true
                            errorMessage = nil
                        }

                        authModeButton(title: "Registrarse", isSelected: !isLoginMode) {
                            isLoginMode = false
                            errorMessage = nil
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(spacing: 16) {
                        if !isLoginMode {
                            Text("Crea tu cuenta")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Group {
                            textField(title: "Nombre de Usuario", text: $username, icon: "person")
                            secureField(title: "Contraseña", text: $password)
                        }

                        if !isLoginMode {
                            textField(title: "Nombre Completo", text: $fullName, icon: "person.text.rectangle")
                            textField(title: "Cédula", text: $nationalId, icon: "person.text.rectangle")
                            textField(title: "Correo Electrónico", text: $email, icon: "envelope")
                                .keyboardType(.emailAddress)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: primaryAction) {
                            Text(isLoginMode ? "Iniciar Sesión" : "Registrarse")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(primaryPink)
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.3))
                        Text("o")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.3))
                    }
                    .padding(.horizontal, 24)

                    Button {
                        errorMessage = "Inicio de sesión con Google aún no está configurado."
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .foregroundColor(.blue)
                            Text("Continuar con Google")
                                .font(.headline)
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 24)
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            locationManager.requestPermissionIfNeeded()
        }
    }

    private func primaryAction() {
        if isLoginMode {
            let success = appData.login(username: username, password: password)
            if !success {
                errorMessage = "Usuario o contraseña incorrectos. Regístrate primero."
            } else {
                errorMessage = nil
            }
        } else {
            let success = appData.register(
                username: username,
                password: password,
                fullName: fullName,
                nationalId: nationalId,
                email: email
            )

            if !success {
                errorMessage = "Por favor completa usuario y contraseña."
            } else {
                errorMessage = nil
            }
        }
    }

    private func authModeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? primaryPink : Color.white)
                .foregroundColor(isSelected ? .white : .primary)
        }
    }

    private func textField(title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                TextField(title, text: text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }

    private func secureField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.secondary)
                SecureField(title, text: text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

