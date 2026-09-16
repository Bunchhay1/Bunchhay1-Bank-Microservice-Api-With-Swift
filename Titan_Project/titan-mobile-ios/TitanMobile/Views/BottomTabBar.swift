import SwiftUI

// MARK: - Custom Bottom Tab Bar
struct BottomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                TabCell(tab: tab, isSelected: selectedTab == tab) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 26)
        .background(
            Rectangle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: -6)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Single Tab Cell
struct TabCell: View {
    let tab: AppTab
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    if isSelected {
                        // Orange-blue pill for active Home, blue for others
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tab == .home ? Color.orangeSoft : Color.titanBlueSoft)
                            .frame(width: 44, height: 30)
                    }
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                        .foregroundColor(
                            isSelected
                                ? (tab == .home ? .orangeMid : .titanBlue)
                                : Color(hex: "#9CA3AF")
                        )
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
                .frame(height: 30)

                Text(tab.title)
                    .font(AppFont.medium(10))
                    .foregroundColor(
                        isSelected
                            ? (tab == .home ? .orangeMid : .titanBlue)
                            : Color(hex: "#9CA3AF")
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack { Spacer(); BottomTabBar(selectedTab: .constant(.home)) }
        .background(Color.appBG)
}
