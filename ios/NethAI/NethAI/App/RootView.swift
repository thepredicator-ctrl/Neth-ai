import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
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
        ZStack {
            NethTheme.voidBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                content
                NethTabBar(selectedTab: $selectedTab)
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
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootView.Tab.allCases) { tab in
                tabItem(tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            NethTheme.charcoal
                .overlay(Rectangle().fill(NethTheme.hairline).frame(height: 0.5), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(_ tab: RootView.Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selectedTab == tab ? NethTheme.orange : NethTheme.textTertiary)
                    .shadow(color: selectedTab == tab ? NethTheme.orange.opacity(0.6) : .clear, radius: 6, y: 1)
                Text(tab.label)
                    .font(.caption2)
                    .foregroundStyle(selectedTab == tab ? NethTheme.textPrimary : NethTheme.textTertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
