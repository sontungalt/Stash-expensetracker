import SwiftUI

struct MoneyLeftEditor: View {
    let currentAmount: Decimal
    let onSave: (Decimal) throws -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var error: String?
    @FocusState private var amountFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize = 44.0

    init(amount: Decimal, onSave: @escaping (Decimal) throws -> Void) {
        currentAmount = amount
        self.onSave = onSave
        _amountText = State(initialValue: NSDecimalNumber(decimal: max(0, amount)).stringValue)
    }

    var body: some View {
        let t = Theme.current(scheme)
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Text("$").foregroundStyle(t.text2).accessibilityHidden(true)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .accessibilityLabel("Money left")
                            .accessibilityIdentifier("balance.amount")
                        Button {
                            amountText = ""
                            amountFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body).foregroundStyle(t.text2)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                        .disabled(amountText.isEmpty)
                        .opacity(amountText.isEmpty ? 0 : 1)
                        .accessibilityHidden(amountText.isEmpty)
                        .accessibilityLabel("Clear amount")
                        .accessibilityIdentifier("balance.clear")
                    }
                    .font(.system(size: amountSize, weight: .medium)).monospacedDigit()
                    .padding(.vertical, 8)
                } header: {
                    Text("Money you have right now")
                } footer: {
                    Text("Currently shown: \(Money.format(currentAmount)). You can enter zero.")
                }
                Section {
                    Label("New spending comes off this balance.", systemImage: "minus.circle")
                    Label("Your allowance still resets on Monday.", systemImage: "calendar")
                } footer: {
                    Text("This updates Overview and Activity. Your transactions stay the same.")
                }
                if let error {
                    Text(error).foregroundStyle(t.danger).accessibilityIdentifier("balance.error")
                }
            }
            .scrollContentBackground(.hidden)
            .background(t.bg)
            .tint(t.ink)
            .safeAreaInset(edge: .top, spacing: 0) { DeletionUndoNotice() }
            .navigationTitle("Edit money left")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("balance.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = CurrentBalance.parseAmount(amountText) else {
                            error = "Enter zero or a positive amount with up to two decimal places, like 1.50."
                            return
                        }
                        do { try onSave(amount); dismiss() }
                        catch { self.error = "Couldn’t save your balance. Please try again." }
                    }
                    .accessibilityIdentifier("balance.save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                        .accessibilityIdentifier("balance.keyboardDone")
                }
            }
            .onChange(of: amountText) { error = nil }
            .task { amountFocused = true }
        }
    }
}
