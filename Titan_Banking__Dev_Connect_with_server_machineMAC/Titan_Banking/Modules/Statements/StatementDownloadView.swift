import SwiftUI

struct StatementDownloadView: View {
    @StateObject private var vm = StatementViewModel()
    @Environment(\.dismiss) private var dismiss
    let accounts: [AccountModel]

    @State private var selectedAccountId: Int = 0
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Picker("Account", selection: $selectedAccountId) {
                        Text("Select").tag(0)
                        ForEach(accounts) { a in
                            Text("\(a.accountNumber)").tag(a.id)
                        }
                    }
                }

                if let err = vm.errorMessage {
                    Section { Text(err).foregroundStyle(Color.titanOutflow) }
                }
                if let ok = vm.successMessage {
                    Section {
                        Text(ok).foregroundStyle(Color.titanInflow)
                    }
                }

                Section {
                    TitanPrimaryButton(
                        label: "Download statement PDF",
                        isLoading: vm.isLoading
                    ) {
                        guard selectedAccountId != 0 else {
                            vm.errorMessage = "Select an account."
                            return
                        }
                        Task {
                            await vm.download(accountId: selectedAccountId)
                            if let data = vm.pdfData {
                                let url = FileManager.default.temporaryDirectory
                                    .appendingPathComponent("titan-statement-\(selectedAccountId).pdf")
                                try? data.write(to: url)
                                shareURL = url
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                if let url = shareURL {
                    Section {
                        ShareLink(item: url) {
                            Label("Share statement.pdf", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Statements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if selectedAccountId == 0 {
                    selectedAccountId = accounts.first?.id ?? 0
                }
            }
        }
    }
}
