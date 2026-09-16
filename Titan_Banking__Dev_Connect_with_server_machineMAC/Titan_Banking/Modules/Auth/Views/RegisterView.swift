import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreed = false
    @State private var showPassword = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.titanBackground.ignoresSafeArea()

            // Red header bar (behind ScrollView — visual only)
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.titanPrimary)
                    .frame(height: 130)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // ScrollView on top — contains header buttons so taps register
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Header area (rendered over the red bar)
                    HStack {
                        Button { dismiss() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("ត្រឡប់")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        VStack(spacing: 2) {
                            Text("បង្កើតគណនីថ្មី")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Create New Account")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Color.clear.frame(width: 80, height: 36)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 90)

                    // ── White card
                    VStack(spacing: 24) {
                        stepIndicator

                        if step == 0 {
                            personalInfoStep
                        } else {
                            credentialsStep
                        }

                        // Only show error on step 1 (API errors)
                        if step == 1, let err = authVM.errorMessage {
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

                        Button(action: handleAction) {
                            ZStack {
                                if authVM.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    HStack(spacing: 6) {
                                        Text(step == 0 ? "បន្ត" : "បង្កើតគណនី")
                                        Text(step == 0 ? "/ Continue" : "/ Create Account")
                                            .opacity(0.85)
                                    }
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(nextEnabled ? Color.titanPrimary : Color.titanPrimary.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!nextEnabled || authVM.isLoading)

                        HStack(spacing: 4) {
                            if step == 1 {
                                Button("← ត្រឡប់ / Back") {
                                    authVM.errorMessage = nil
                                    withAnimation { step = 0 }
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.titanSecondary)
                                Spacer()
                            } else {
                                Spacer()
                            }
                            Button("មានគណនីហើយ? / Login") { dismiss() }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.titanPrimary)
                        }
                    }
                    .padding(24)
                    .background(Color.titanBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.07), radius: 16, y: -2)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { authVM.errorMessage = nil }
    }

    // MARK: - Step Indicator
    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(0..<2) { i in
                HStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(i <= step ? Color.titanPrimary : Color.titanPrimary.opacity(0.15))
                            .frame(width: 28, height: 28)
                        if i < step {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(i + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(i == step ? .white : Color.titanPrimary.opacity(0.5))
                        }
                    }
                    if i < 1 {
                        Rectangle()
                            .fill(step > 0 ? Color.titanPrimary : Color.titanPrimary.opacity(0.15))
                            .frame(maxWidth: .infinity)
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private var personalInfoStep: some View {
        VStack(spacing: 14) {
            sectionLabel("ព័ត៌មានផ្ទាល់ខ្លួន / Personal Info")

            KhmerInputField(icon: "person.fill",
                            placeholder: "នាមត្រកូល / First Name",
                            text: $firstName)

            KhmerInputField(icon: "person.fill",
                            placeholder: "នាម / Last Name",
                            text: $lastName)

            KhmerInputField(icon: "phone.fill",
                            placeholder: "លេខទូរស័ព្ទ / Phone Number",
                            text: $phone,
                            keyboard: .phonePad)

            KhmerInputField(icon: "envelope.fill",
                            placeholder: "អ៊ីម៉ែល / Email (optional)",
                            text: $email,
                            keyboard: .emailAddress)
        }
    }

    // MARK: - Step 1: Credentials
    private var credentialsStep: some View {
        VStack(spacing: 14) {
            sectionLabel("ព័ត៌មានចូល / Login Credentials")

            KhmerInputField(icon: "person.text.rectangle",
                            placeholder: "Username",
                            text: $username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            // Password
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.titanPrimary)
                    .frame(width: 20)
                Group {
                    if showPassword { TextField("ពាក្យសម្ងាត់ / Password", text: $password) }
                    else            { SecureField("ពាក្យសម្ងាត់ / Password", text: $password) }
                }
                .frame(maxWidth: .infinity)
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.titanSecondary)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.titanRedLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Confirm password
            HStack(spacing: 12) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.titanPrimary)
                    .frame(width: 20)
                SecureField("បញ្ជាក់ពាក្យសម្ងាត់ / Confirm Password", text: $confirmPassword)
                if !confirmPassword.isEmpty {
                    Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(password == confirmPassword ? Color.titanInflow : Color.titanPrimary)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.titanRedLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Password strength
            if !password.isEmpty {
                PasswordStrengthBar(password: password)
            }

            // Terms
            Button { agreed.toggle() } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: agreed ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(agreed ? Color.titanPrimary : Color.titanSecondary)
                    Text("ខ្ញុំយល់ព្រមតាម ")
                        .font(.caption)
                        .foregroundStyle(Color.titanSecondary)
                    Text("លក្ខខណ្ឌ / Terms & Conditions")
                        .font(.caption)
                        .foregroundStyle(Color.titanPrimary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, weight: .semibold))
            .tracking(0.3)
            .foregroundStyle(Color.titanSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nextEnabled: Bool {
        if step == 0 { return !firstName.isEmpty && !lastName.isEmpty && !phone.isEmpty }
        return !username.isEmpty && password.count >= 6
               && password == confirmPassword && agreed
    }

    private func handleAction() {
        if step == 0 {
            withAnimation { step = 1 }
        } else {
            Task {
                await authVM.register(
                    username: username, password: password,
                    email: email, firstName: firstName, lastName: lastName
                )
            }
        }
    }
}

// MARK: - Password Strength Bar
struct PasswordStrengthBar: View {
    let password: String

    private var score: Int {
        var s = 0
        if password.count >= 8   { s += 1 }
        if password.count >= 12  { s += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { s += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { s += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { s += 1 }
        return s
    }

    private var label: String {
        switch score {
        case 0...1: return "ខ្សោយ / Weak"
        case 2...3: return "មធ្យម / Fair"
        default:    return "រឹងមាំ / Strong"
        }
    }

    private var barColor: Color {
        switch score {
        case 0...1: return Color.titanPrimary
        case 2...3: return .orange
        default:    return Color.titanInflow
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.titanPrimary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * min(CGFloat(score) / 5.0, 1.0))
                        .animation(.easeInOut, value: score)
                }
            }
            .frame(height: 4)
            Text(label)
                .font(.caption2)
                .foregroundStyle(barColor)
        }
    }
}
