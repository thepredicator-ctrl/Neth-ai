import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .assistant

    enum Tab: String, CaseIterable, Identifiable {
        case assistant, conversations, models, settings
        var id: String { rawValue }

        var label: String {
            switch self {
            case .assistant:     return "Assistant"
            case .conversations: return "Chats"
            case .models:        return "Models"
            case .settings:      return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .assistant:     return "circle.fill"
            case .conversations: return "bubble.left.and.bubble.right.fill"
            case .models:        return "cube.fill"
            case .settings:      return "gearshape.fill"
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                NethTheme.voidBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    NethTabBar(selectedTab: $selectedTab)
                }
            }
        }
        .tint(NethTheme.orange)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .assistant:     AssistantView()
        case .conversations: ConversationsView()
        case .models:        ModelsView()
        case .settings:      SettingsView()
        }
    }
}

// MARK: - Custom tab bar with glowing accent

struct NethTabBar: View {
    @Binding var selectedTab: RootView.Tab
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootView.Tab.allCases) { tab in
                tabItem(tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            ZStack {
                NethTheme.charcoal
                LinearGradient(
                    colors: [NethTheme.orange.opacity(0.05), .clear],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .overlay(Rectangle().fill(NethTheme.hairline).frame(height: 0.5), alignment: .top)
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(_ tab: RootView.Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if selectedTab == tab {
                        Circle()
                            .fill(NethTheme.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .blur(radius: 4)
                    }
                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? NethTheme.orange : NethTheme.textTertiary)
                        .scaleEffect(selectedTab == tab ? 1.05 : 1.0)
                }
                Text(tab.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selectedTab == tab ? NethTheme.textPrimary : NethTheme.textTertiary)
                    .tracking(0.5)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
