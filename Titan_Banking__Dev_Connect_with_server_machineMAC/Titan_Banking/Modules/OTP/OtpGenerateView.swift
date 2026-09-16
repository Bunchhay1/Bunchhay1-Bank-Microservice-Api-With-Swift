import SwiftUI

struct OtpGenerateView: View {
    @StateObject private var vm = OtpViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.titanPrimary)
                    .padding(.top, 32)

                Text("One-Time Password")
                    .font(.title2.bold())

                Text("Generate an OTP for high-value transfers. The code is stored in Redis and logged on the server.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let msg = vm.message {
                    VStack(spacing: 8) {
                        Text(msg)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        if let status = vm.status {
                            Text(status)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.titanPrimary)
                        }
                        if let otp = vm.otpCode {
                            Text(otp)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.titanInflow)
                                .padding(.top, 4)
                            Text("Test mode — OTP shown in response")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.titanPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Color.titanOutflow)
                        .padding(.horizontal)
                }

                TitanPrimaryButton(label: "Generate OTP", isLoading: vm.isLoading) {
                    Task { await vm.generate() }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("OTP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
