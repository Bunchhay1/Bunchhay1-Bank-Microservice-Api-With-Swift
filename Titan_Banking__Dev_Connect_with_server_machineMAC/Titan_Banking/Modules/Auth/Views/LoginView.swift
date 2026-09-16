import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var username = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showPassword = false

    // ✅ Fix 1: LAContext kept alive as @State so it isn't deallocated before callback
    @State private var laContext = LAContext()

    var body: some View {
        // ✅ Fix 3: NavigationStack only here; RegisterView uses @Environment(\.dismiss)
        NavigationStack {
            ZStack(alignment: .top) {
                Color.titanBackground.ignoresSafeArea()
                redHeaderWave

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 220)

                        VStack(spacing: 24) {
                            VStack(spacing: 4) {
                                Text("ចូលគណនី")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color.titanDark)   // ✅ Fix 2: defined below
                                Text("Sign in to your account")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.titanSecondary)
                            }

                            VStack(spacing: 14) {
                                KhmerInputField(
                                    icon: "person.fill",
                                    placeholder: "លេខទូរស័ព្ទ / Username",
                                    text: $username
                                )
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                HStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.titanPrimary)
                                        .frame(width: 20)
                                    Group {
                                        if showPassword {
                                            TextField("ពាក្យសម្ងាត់ / Password", text: $password)
                                        } else {
                                            SecureField("ពាក្យសម្ងាត់ / Password", text: $password)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .font(.system(size: 15))
                                            .foregroundStyle(Color.titanSecondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(Color.titanRedLight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            HStack {
                                Spacer()
                                Button("ភ្លេចពាក្យសម្ងាត់? / Forgot Password?") {}
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.titanPrimary)
                            }

                            if let err = authVM.errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text(err).font(.caption)
                                }
                                .foregroundStyle(Color.titanPrimary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.titanPrimary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button {
                                Task { await authVM.login(username: username, password: password) }
                            } label: {
                                ZStack {
                                    if authVM.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        HStack(spacing: 8) {
                                            Text("ចូល")
                                                .font(.system(size: 17, weight: .bold))
                                            Text("/ Login")
                                                .font(.system(size: 17, weight: .semibold))
                                                .opacity(0.85)
                                        }
                                        .foregroundStyle(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    (username.isEmpty || password.isEmpty)
                                    ? Color.titanPrimary.opacity(0.45)
                                    : Color.titanPrimary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(authVM.isLoading || username.isEmpty || password.isEmpty)

                            biometricButton

                            Divider()

                            HStack(spacing: 4) {
                                Text("មិនទាន់មានគណនី?")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.titanSecondary)
                                // ✅ Fix 3: navigationDestination push (not sheet)
                                Button("បង្កើតគណនី / Register") {
                                    showRegister = true
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.titanPrimary)
                            }
                        }
                        .padding(28)
                        .background(Color.titanBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 20, y: -4)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }

    // MARK: - Header with Angkor Wat background
    private var redHeaderWave: some View {
        ZStack(alignment: .center) {
            // ── Angkor Wat photo clipped to wave shape ────────────────────────
            WaveShape()
                .frame(height: 260)
                .ignoresSafeArea(edges: .top)
                .overlay(
                    ZStack {
                        // Photo fills the wave
                        Image("angkor_wat")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .clipped()

                        // Blue-tinted overlay so text is readable (ABA blue tint)
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.18, blue: 0.58).opacity(0.82),
                                Color(red: 0.08, green: 0.32, blue: 0.78).opacity(0.70)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    }
                    .clipShape(WaveShape())
                )

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 76, height: 76)
                        .shadow(color: .black.opacity(0.15), radius: 8)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.titanPrimary)
                }
                Text("TITAN")
                    .font(.system(size: 22, weight: .black))
                    .tracking(5)
                    .foregroundStyle(.white)
                Text("ធនាគារ ទីតែន")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.top, 24)
        }
    }

    // MARK: - Biometric Button
    // ✅ Fix 1+2: @State laContext stays alive; result dispatched on main thread
    private var biometricButton: some View {
        var checkErr: NSError?
        let hasBio = laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &checkErr)
        let isFaceID = laContext.biometryType == .faceID
        let icon  = isFaceID ? "faceid" : "touchid"
        let label = isFaceID ? "Face ID" : "Touch ID"

        return Group {
            if hasBio {
                Button {
                    laContext.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: "ចូលដោយ \(label)"
                    ) { success, _ in
                        DispatchQueue.main.async {
                            if success {
                                // Biometric passed — reset context for next use
                                laContext = LAContext()
                                // In production: exchange biometric token for JWT here.
                                // For demo, surface a notice; real login requires credentials.
                                authVM.errorMessage = "Biometric verified. Enter credentials to continue."
                            } else {
                                laContext = LAContext() // reset after failure
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                        Text("ចូលដោយ \(label)")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color.titanPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.titanPrimary.opacity(0.35), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Wave Shape
struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 40))
        p.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - 40),
            control: CGPoint(x: rect.midX, y: rect.maxY + 30)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Khmer Input Field
struct KhmerInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.titanPrimary)
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.titanRedLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
