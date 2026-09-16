import SwiftUI

struct FixedDepositView: View {
    @StateObject private var vm = FixedDepositViewModel()
    @Environment(\.dismiss) private var dismiss
    let accounts: [AccountModel]

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Picker("Account", selection: Binding(
                        get: { vm.selectedAccountId ?? 0 },
                        set: { vm.selectedAccountId = $0 == 0 ? nil : $0 }
                    )) {
                        Text("Select").tag(0)
                        ForEach(accounts) { a in
                            Text("\(a.accountNumber) · \(a.balance, format: .currency(code: a.currency))")
                                .tag(a.id)
                        }
                    }
                }

                Section("Deposit") {
                    TextField("Principal amount", text: $vm.amountText)
                        .keyboardType(.decimalPad)
                    Picker("Term (months)", selection: $vm.termMonths) {
                        ForEach(vm.termOptions, id: \.self) { m in
                            Text("\(m) months").tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Interest rate is 6% p.a. (server fixed).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let err = vm.errorMessage {
                    Section { Text(err).foregroundStyle(Color.titanOutflow) }
                }
                if let ok = vm.successMessage, let fd = vm.created {
                    Section("Created") {
                        Text(ok).foregroundStyle(Color.titanInflow)
                        Text("Status: \(fd.status ?? "ACTIVE")")
                        if let mat = fd.maturityDate {
                            Text("Matures: \(mat)")
                        }
                    }
                }

                Section {
                    TitanPrimaryButton(label: "Open fixed deposit", isLoading: vm.isLoading) {
                        Task {
                            if await vm.submit() {
                                try? await Task.sleep(for: .seconds(1.2))
                                dismiss()
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Fixed Deposit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if vm.selectedAccountId == nil {
                    vm.selectedAccountId = accounts.first?.id
                }
            }
        }
    }
}
