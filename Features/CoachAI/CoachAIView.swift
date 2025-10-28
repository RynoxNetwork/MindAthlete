import SwiftUI

struct CoachAIView: View {
    @StateObject private var viewModel: CoachAIViewModel
    @State private var tipEscalation: EscalationResponseDTO?
    @Environment(\.openURL) private var openURL

    init(viewModel: CoachAIViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: MASpacing.lg) {
            if let tip = viewModel.dailyTip {
                dailyTipCard(for: tip)
                    .padding(.horizontal, MASpacing.lg)
            }

            ChatView(viewModel: viewModel.chatViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.maBackground.ignoresSafeArea())
        .navigationTitle("Coach IA")
        .task {
            await viewModel.load()
        }
        .alert("Acompañamiento profesional", isPresented: Binding(
            get: { tipEscalation != nil },
            set: { if !$0 { tipEscalation = nil } }
        )) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(tipEscalation?.message ?? "Registramos tu solicitud.")
        }
    }

    @ViewBuilder
    private func dailyTipCard(for tip: DailyRecommendationResponseDTO) -> some View {
        MACard(title: "Sugerencia del día") {
            VStack(alignment: .leading, spacing: MASpacing.sm) {
                Text(tip.recommendations.first ?? "Comparte con Kai tus retos para recibir una sugerencia personalizada.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(MAColorPalette.textPrimary)

                if let rationale = tip.rationale {
                    Text(rationale)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let event = tip.eventContext.first {
                    Label("\(event.title) • \(Self.timeFormatter.string(from: event.start))", systemImage: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: MASpacing.sm) {
                    MAButton("Abrir chat", style: .secondary) {
                        viewModel.trackChatCTA()
                    }

                    if tip.escalate {
                        MAButton("Solicitar apoyo", style: .primary) {
                            Task {
                                if let response = await viewModel.escalateFromDailyTip() {
                                    if response.escalate, let url = response.bookingURL {
                                        openURL(url)
                                    } else {
                                        tipEscalation = response
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Environment(
        \.openURL
    ) private var openURL
    @State private var showHabitPlan = false
    @State private var escalationAlert: EscalationResponseDTO?

    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MASpacing.md) {
                        ForEach(viewModel.messages) { message in
                            messageBubble(for: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, MASpacing.lg)
                    .padding(.vertical, MASpacing.md)
                    .background(Color.maBackground)
                }
                .onChange(of: viewModel.messages) { messages in
                    guard let last = messages.last else { return }
                    withAnimation(.easeOut) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            if viewModel.pendingEscalation {
                escalationBanner
                    .padding(.horizontal, MASpacing.lg)
                    .padding(.vertical, MASpacing.sm)
                    .background(Color.maSurface)
            }

            inputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.maSurface)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await viewModel.generateHabitPlan()
                        showHabitPlan = viewModel.habitPlan != nil
                    }
                } label: {
                    if viewModel.isGeneratingPlan {
                        ProgressView()
                    } else {
                        Label("Plan", systemImage: "list.bullet.rectangle")
                    }
                }
                .disabled(viewModel.isGeneratingPlan)
            }
        }
        .task {
            await viewModel.loadHistory()
        }
        .sheet(isPresented: $showHabitPlan, onDismiss: {
            showHabitPlan = false
        }) {
            if let plan = viewModel.habitPlan {
                HabitPlanSheet(plan: plan)
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Ups", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Acompañamiento profesional", isPresented: Binding(
            get: { escalationAlert != nil },
            set: { if !$0 { escalationAlert = nil } }
        )) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(escalationAlert?.message ?? "Registramos tu solicitud.")
        }
    }

    private func messageBubble(for message: ChatViewModel.Message) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: MASpacing.xs) {
                Text(message.content)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(isUser ? Color.white : MAColorPalette.textPrimary)
                    .padding(.horizontal, MASpacing.md)
                    .padding(.vertical, MASpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isUser ? MAColorPalette.primary : MAColorPalette.surfaceAlt)
                    )
                if message.isStreaming {
                    ProgressView()
                        .scaleEffect(0.66)
                        .tint(isUser ? Color.white : MAColorPalette.primary)
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
        .transition(.opacity.combined(with: .move(edge: isUser ? .trailing : .leading)))
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: MASpacing.xs) {
            if let hint = viewModel.habitHint, !hint.isEmpty {
                Button {
                    Task {
                        await viewModel.generateHabitPlan()
                        showHabitPlan = viewModel.habitPlan != nil
                    }
                } label: {
                    HStack(spacing: MASpacing.xs) {
                        Image(systemName: "sparkles")
                        Text("Kai sugiere: \(hint)")
                        Spacer()
                        Text("Generar plan")
                            .fontWeight(.semibold)
                    }
                    .font(.footnote)
                    .padding(MASpacing.sm)
                    .background(RoundedRectangle(cornerRadius: 12).fill(MAColorPalette.primary.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .bottom, spacing: MASpacing.sm) {
                TextField("Comparte tu reto de hoy…", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3)

                Button {
                    viewModel.sendCurrentMessage()
                } label: {
                    Image(systemName: viewModel.isSending ? "hourglass" : "paperplane.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MAColorPalette.primary)
                }
                .disabled(viewModel.isSending || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, MASpacing.lg)
        .padding(.vertical, MASpacing.sm)
        .background(Color.maSurface)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 1),
            alignment: .top
        )
    }

    private var escalationBanner: some View {
        VStack(alignment: .leading, spacing: MASpacing.xs) {
            HStack(spacing: MASpacing.sm) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundStyle(MAColorPalette.primary)
                Text("Kai recomienda apoyo adicional")
                    .font(.system(.headline, design: .rounded))
            }
            Text("Podemos conectar contigo con un psicólogo deportivo para seguir acompañándote.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                MAButton("Solicitar apoyo", style: .secondary) {
                    Task {
                        if let response = await viewModel.escalate() {
                            if response.escalate, let url = response.bookingURL {
                                openURL(url)
                            } else {
                                escalationAlert = response
                            }
                        }
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(MASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MAColorPalette.primary.opacity(0.08))
        )
    }
}

private struct HabitPlanSheet: View {
    let plan: HabitPlanResponseDTO

    var body: some View {
        NavigationStack {
            List {
                Section("Plan de hábitos") {
                    if let summary = plan.summary {
                        Text(summary)
                    }
                }

                ForEach(plan.habits) { habit in
                    VStack(alignment: .leading, spacing: MASpacing.xs) {
                        Text(habit.title)
                            .font(.headline)
                        if let rationale = habit.rationale {
                            Text(rationale)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: MASpacing.sm) {
                            Label(habit.frequency.capitalized, systemImage: "repeat")
                                .font(.caption)
                            if let start = habit.recommendedStartDate {
                                Label(HabitPlanSheet.dateFormatter.string(from: start), systemImage: "calendar")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, MASpacing.xs)
                }
            }
            .navigationTitle("Nuevo plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
