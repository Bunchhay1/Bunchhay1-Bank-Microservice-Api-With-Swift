import SwiftUI

// MARK: - Root Content View
struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(AppTab.home)

                PlaceholderView(title: "Accounts",  icon: "creditcard.fill")
                    .tag(AppTab.accounts)

                PlaceholderView(title: "Transfers", icon: "arrow.left.arrow.right.circle.fill")
                    .tag(AppTab.transfers)

                PlaceholderView(title: "Loans",     icon: "doc.text.fill")
                    .tag(AppTab.loans)

                PlaceholderView(title: "More",      icon: "ellipsis.circle.fill")
                    .tag(AppTab.more)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            BottomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Placeholder for other tabs
struct PlaceholderView: View {
    let title: String
    let icon: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.titanBlue.opacity(0.35))
            Text(title)
                .font(AppFont.semibold(20))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBG.ignoresSafeArea())
    }
}

#Preview { ContentView() }
