import SwiftUI

struct ConversationsView: View {
    @Environment(AppState.self) private var appState
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
            List {
                if filtered.isEmpty {
                    Text("No conversations yet. Start one from the Assistant tab.")
                        .foregroundStyle(NethTheme.textSecondary)
                } else {
                    ForEach(filtered) { convo in
                        NavigationLink {
                            ConversationDetailView(conversation: convo)
                        } label: {
                            ConversationRow(conversation: convo)
                        }
                        .contextMenu {
                            Button("Rename") {
                                renaming = convo
                                renameText = convo.title
                            }
                            Button("Delete", role: .destructive) {
                                Task { await delete(convo) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            .searchable(text: $searchText, prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await newConversation() }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(NethTheme.orange)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(conversation.title)
                    .font(.headline)
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
            if let m = conversation.modelName {
                HStack(spacing: 4) {
                    Image(systemName: "cube.fill").font(.system(size: 8))
                    Text(m).font(.caption2)
                }
                .foregroundStyle(NethTheme.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ConversationDetailView: View {
    let conversation: Conversation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(conversation.messages) { msg in
                    MessageBlock(message: msg)
                }
            }
            .padding()
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MessageBlock: View {
    let message: ChatMessage
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
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
            if let stats = message.stats {
                Text(stats.formattedSummary)
                    .font(NethTheme.monoFont)
                    .foregroundStyle(NethTheme.textTertiary)
            }
        }
        .padding(12)
        .background(NethTheme.charcoal.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
