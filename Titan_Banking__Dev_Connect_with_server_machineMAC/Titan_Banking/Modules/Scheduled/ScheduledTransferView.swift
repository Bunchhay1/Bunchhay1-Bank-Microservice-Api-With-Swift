import SwiftUI

struct ScheduledTransferView: View {
    @StateObject private var vm = ScheduledTransferViewModel()
    @Environment(\.dismiss) private var dismiss
    let accounts: [AccountModel]

    var body: some View {
        NavigationStack {
            Form {
                Section("From") {
                    Picker("Account", selection: $vm.fromAccountNumber) {
                        Text("Select").tag("")
                        ForEach(accounts) { a in
                            Text(a.accountNumber).tag(a.accountNumber)
                        }
                    }
                }
                Section("To & amount") {
                    TextField("To account number", text: $vm.toAccountNumber)
                        .keyboardType(.numberPad)
                    TextField("Amount", text: $vm.amountText)
                        .keyboardType(.decimalPad)
                    TextField("Note", text: $vm.note)
                    SecureField("PIN", text: $vm.pin)
                        .keyboardType(.numberPad)
                    Text("Server schedules execution for tomorrow (PENDING).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let err = vm.errorMessage {
                    Section { Text(err).foregroundStyle(Color.titanOutflow) }
                }
                if let ok = vm.successMessage {
                    Section { Text(ok).foregroundStyle(Color.titanInflow) }
                }

                Section {
                    TitanPrimaryButton(label: "Schedule payment", isLoading: vm.isLoading) {
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
            .navigationTitle("Scheduled")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if vm.fromAccountNumber.isEmpty, let first = accounts.first {
                    vm.fromAccountNumber = first.accountNumber
                }
            }
        }
    }
}
