import SwiftUI

struct ConversationsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var renaming: Conversation?
    @State private var renameText: String = ""

    var filtered: [Conversation] {
        if searchText.isEmpty { return appState.conversations }
        return appState.conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.messages.contains(where: { $0.content.localizedCaseInsensitiveContains(searchText) })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NethTheme.voidBlack.ignoresSafeArea()

                Group {
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(filtered) { convo in
                                NavigationLink {
                                    ConversationDetailView(conversation: convo)
                                } label: {
                                    ConversationRow(conversation: convo)
                                }
                                .listRowBackground(NethTheme.charcoal.opacity(0.4))
                                .listRowSeparatorTint(NethTheme.hairline)
                                .contextMenu {
                                    Button {
                                        renaming = convo
                                        renameText = convo.title
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        Task { await delete(convo) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search conversations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await newConversation() }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(NethTheme.orange)
                            .font(.system(size: 22))
                    }
                }
            }
            .alert("Rename Conversation", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Save") {
                    if let c = renaming {
                        Task { await rename(c, to: renameText) }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(NethTheme.orange.opacity(0.7))
                .shadow(color: NethTheme.orange.opacity(0.4), radius: 14)
            Text("No conversations yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(NethTheme.textPrimary)
            Text("Start one from the Assistant tab.")
                .font(.subheadline)
                .foregroundStyle(NethTheme.textTertiary)
        }
    }

    private func newConversation() async {
        let c = Conversation(title: "Conversation \(appState.conversations.count + 1)")
        try? ConversationStore.shared.save(c)
        appState.conversations.insert(c, at: 0)
        appState.currentConversation = c
    }

    private func delete(_ convo: Conversation) async {
        try? ConversationStore.shared.delete(convo)
        appState.conversations.removeAll { $0.id == convo.id }
        if appState.currentConversation?.id == convo.id {
            appState.currentConversation = appState.conversations.first
        }
    }

    private func rename(_ convo: Conversation, to name: String) async {
        try? ConversationStore.shared.rename(convo, to: name)
        await appState.refreshConversations()
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    private var lastMessage: String {
        conversation.messages.last?.content.prefix(80).description ?? "No messages"
    }
    private var lastTime: String {
        RelativeDateTimeFormatter().localizedString(for: conversation.updatedAt, relativeTo: Date())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(conversation.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NethTheme.textPrimary)
                Spacer()
                Text(lastTime)
                    .font(.caption2)
                    .foregroundStyle(NethTheme.textTertiary)
            }
            Text(lastMessage)
                .font(.caption)
                .foregroundStyle(NethTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let m = conversation.modelName {
                HStack(spacing: 4) {
                    Circle()
                        .fill(NethTheme.orange)
                        .frame(width: 5, height: 5)
                    Text(m)
                        .font(.caption2)
                }
                .foregroundStyle(NethTheme.orange)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ConversationDetailView: View {
    let conversation: Conversation

    var body: some View {
        ZStack {
            NethTheme.voidBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(conversation.messages) { msg in
                        MessageBlock(message: msg)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MessageBlock: View {
    let message: ChatMessage
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: message.role == .user ? "person.fill" : "sparkle")
                    .font(.caption2)
                Text(message.role.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(message.role == .user ? NethTheme.orange : NethTheme.textTertiary)
                Spacer()
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(NethTheme.textTertiary)
            }
            Text(message.content)
                .font(.body)
                .foregroundStyle(NethTheme.textPrimary)
                .textSelection(.enabled)
            if let stats = message.stats {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                    Text(stats.formattedSummary)
                }
                .font(NethTheme.monoFont)
                .foregroundStyle(NethTheme.textTertiary)
            }
        }
        .padding(14)
        .background(NethTheme.charcoal.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(NethTheme.hairlineWarm.opacity(0.5), lineWidth: 1)
        )
    }
}
