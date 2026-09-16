import SwiftUI

struct InternationalTransferView: View {
    @StateObject private var vm = InternationalTransferViewModel()
    @Environment(\.dismiss) private var dismiss
    let accounts: [AccountModel]

    var body: some View {
        NavigationStack {
            Form {
                Section("From account") {
                    Picker("Account", selection: $vm.fromAccountNumber) {
                        Text("Select").tag("")
                        ForEach(accounts) { a in
                            Text("\(a.accountNumber) · \(a.balance, format: .currency(code: a.currency))")
                                .tag(a.accountNumber)
                        }
                    }
                }

                Section("Transfer details") {
                    TextField("Amount (USD)", text: $vm.amountText)
                        .keyboardType(.decimalPad)
                    TextField("SWIFT code", text: $vm.swiftCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("IBAN", text: $vm.iban)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Note (optional)", text: $vm.note)
                    SecureField("PIN", text: $vm.pin)
                        .keyboardType(.numberPad)
                }

                if let err = vm.errorMessage {
                    Section {
                        Text(err).foregroundStyle(Color.titanOutflow)
                    }
                }
                if let ok = vm.successMessage {
                    Section {
                        Text(ok).foregroundStyle(Color.titanInflow)
                    }
                }

                Section {
                    TitanPrimaryButton(label: "Send internationally", isLoading: vm.isLoading) {
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
            .navigationTitle("International")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                vm.accounts = accounts
                if vm.fromAccountNumber.isEmpty, let first = accounts.first {
                    vm.fromAccountNumber = first.accountNumber
                }
            }
        }
    }
}
