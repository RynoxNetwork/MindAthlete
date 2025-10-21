#if DEMO_UI
import SwiftUI

struct HabitsDemoView: View {
    @StateObject private var vm = HabitsDemoViewModel()
    @State private var showNewHabit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    if vm.isLoading {
                        skeleton
                    } else if vm.activeHabits.isEmpty {
                        emptyState
                    } else {
                        DashboardHeaderDemo(vm: vm)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.easeOut(duration: reduceMotion ? 0 : 0.18), value: vm.activeHabits.count)

                        if vm.activeHabits.count >= vm.freeTierActiveHabitLimit {
                            freeTierBanner
                        }

                        ActiveHabitsList(vm: vm)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Hábitos activos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nuevo hábito") { showNewHabit = true }
                        .buttonStyle(.bordered)
                }
            }
            .sheet(isPresented: $showNewHabit) {
                NewHabitSheetDemo(vm: vm)
                    .presentationDetents([.medium, .large])
            }
            .overlay(alignment: .top) {
                if let error = vm.errorMessage {
                    errorBanner(error)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Hábitos activos")
                .font(.title2.weight(.semibold))
            Spacer()
            Button("Nuevo hábito") { showNewHabit = true }
                .buttonStyle(.borderedProminent)
                .tint(BrandPalette.turquoise)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var skeleton: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 24).fill(.gray.opacity(0.2)).frame(height: 120).redacted(reason: .placeholder)
            RoundedRectangle(cornerRadius: 24).fill(.gray.opacity(0.2)).frame(height: 88).redacted(reason: .placeholder)
            RoundedRectangle(cornerRadius: 24).fill(.gray.opacity(0.2)).frame(height: 88).redacted(reason: .placeholder)
        }
        .shimmer()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Aún no tienes hábitos activos")
                .font(.headline)
            Button("Crear tu primer hábito") { showNewHabit = true }
                .buttonStyle(.borderedProminent)
                .tint(BrandPalette.turquoise)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 8)
        )
    }

    private var freeTierBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(BrandPalette.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Límite de 3 hábitos activos (Free)")
                    .font(.subheadline.weight(.semibold))
                Text("Actualiza para añadir más hábitos.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Mejorar") {}
                .buttonStyle(.bordered)
                .tint(BrandPalette.turquoise)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(BrandPalette.orange.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .padding()
    }
}

// MARK: - Active Habits List
private struct ActiveHabitsList: View {
    @ObservedObject var vm: HabitsDemoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Tus hábitos")
            ForEach(vm.activeHabits) { habit in
                HabitCardDemo(
                    habit: habit,
                    streak: vm.currentStreak(for: habit, logs: vm.logs),
                    monthlyAdherence: vm.monthlyAdherence(vm.logs, for: habit).last ?? 0,
                    weekProgress: vm.weekProgress(for: habit, logs: vm.logs, in: vm.currentWeekInterval()),
                    onCheckToday: { partial in vm.toggleToday(for: habit, partial: partial) },
                    onAddNote: { /* Could present a sheet; simplified */ }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
}

// MARK: - Utilities
private extension View {
    func shimmer() -> some View {
        self
            .redacted(reason: .placeholder)
            .overlay(
                LinearGradient(gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.6), Color.clear]), startPoint: .leading, endPoint: .trailing)
                    .rotationEffect(.degrees(20))
                    .blendMode(.plusLighter)
                    .mask(self)
                    .opacity(0.6)
            )
    }
}

#Preview("Hábitos – vacío Light") {
    HabitsDemoView()
        .preferredColorScheme(.light)
}

#Preview("Hábitos – algunos hábitos Dark") {
    HabitsDemoView()
        .preferredColorScheme(.dark)
}
#endif
