import SwiftUI

/// Dev/simulator screen for POST /api/v1/atm/redeem (ATM terminal side).
struct AtmRedeemView: View {
    @StateObject private var vm = AtmViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Simulates a Titan ATM redeeming a cardless withdrawal code.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Redeem") {
                    TextField("12-digit code", text: $vm.redeemCode)
                        .keyboardType(.numberPad)
                        .font(.system(.body, design: .monospaced))
                    TextField("Terminal ID", text: $vm.redeemTerminalId)
                        .textInputAutocapitalization(.characters)
                }

                if let err = vm.errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }

                if let result = vm.redeemResult {
                    Section("Result") {
                        LabeledContent("Status", value: result.status)
                        LabeledContent("Account", value: result.accountNumber)
                        LabeledContent("Amount", value: result.amount.formatted(.currency(code: "USD")))
                        if let msg = result.message {
                            Text(msg).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await vm.redeemCode() }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isLoading {
                                ProgressView()
                            } else {
                                Label("Redeem at ATM", systemImage: "banknote")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(vm.isLoading)
                }
            }
            .navigationTitle("ATM Redeem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
