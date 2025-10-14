import SwiftUI

struct HabitCreationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var target: Int = 5
    @State private var active: Bool = true

    @State private var showValidation: Bool = false
    @FocusState private var nameFocused: Bool

    var onSave: (Habit) -> Void

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValidName: Bool { trimmedName.count >= 2 }

    var body: some View {
        Form {
            // Información básica
            Section(header: Text("Información básica")) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                    TextField("Nombre del hábito", text: $name)
                        .focused($nameFocused)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                }
                .accessibilityElement(children: .combine)

                HStack {
                    Spacer()
                    Text("\(name.count)/40")
                        .font(.caption)
                        .foregroundStyle(name.count > 40 ? .red : .secondary)
                }
                .onChange(of: name) { new in
                    if new.count > 40 { name = String(new.prefix(40)) }
                }

                if showValidation && !isValidName {
                    Label("El nombre debe tener al menos 2 caracteres.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityHint("Nombre demasiado corto")
                }
            }

            // Meta semanal
            Section(header: Text("Meta semanal"), footer: Text("Sugerencia: elige una meta alcanzable. 5–7 veces suele funcionar bien.")) {
                Stepper(value: $target, in: 1...14) {
                    Text("\(target) veces por semana")
                }

                // Accesos rápidos
                Picker("Rápidos", selection: $target) {
                    Text("3").tag(3)
                    Text("5").tag(5)
                    Text("7").tag(7)
                    Text("10").tag(10)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Accesos rápidos de meta")
            }

            // Estado
            Section(header: Text("Estado")) {
                Toggle(isOn: $active) {
                    Label("Activo", systemImage: active ? "checkmark.circle.fill" : "circle")
                }
            }

            // Vista previa
            Section(header: Text("Vista previa")) {
                HabitPreviewCard(name: isValidName ? trimmedName : "Nombre pendiente",
                                 target: target,
                                 active: active)
            }

            // Guardar
            Section {
                MAButton("Guardar", style: .primary) {
                    showValidation = true
                    guard isValidName else { return }

                    let habit = Habit(
                        id: UUID().uuidString,
                        userId: "",
                        name: trimmedName,
                        targetPerWeek: target,
                        active: active
                    )
                    onSave(habit)
                    dismiss()
                }
                .disabled(!isValidName)
                .accessibilityHint(!isValidName ? "Introduce un nombre válido para habilitar Guardar" : "Guardar hábito")
            }
        }
        .navigationTitle("Nuevo hábito")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { nameFocused = true }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancelar") { dismiss() }
        }
    }
}

// MARK: - Vista previa auxiliar
private struct HabitPreviewCard: View {
    let name: String
    let target: Int
    let active: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(active ? Color.green.opacity(0.2) : Color.gray.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: active ? "bolt.fill" : "pause")
                    .foregroundStyle(active ? .green : .gray)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                Text("Meta: \(target) / semana")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: active ? "checkmark.circle" : "xmark.circle")
                        .foregroundStyle(active ? .green : .red)
                    Text(active ? "Activo" : "Inactivo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vista previa del hábito: \(name), meta \(target) por semana, estado \(active ? "activo" : "inactivo")")
    }
}

#Preview {
    NavigationStack {
        HabitCreationView { _ in }
    }
}
