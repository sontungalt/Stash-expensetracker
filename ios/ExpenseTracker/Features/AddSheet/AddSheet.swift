import SwiftData
import SwiftUI

struct AddSheet: View {
    let request: SheetRequest
    let store: TransactionStore
    let onDelete: (Entry) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(StashCompanion.self) private var stash
    @Query(sort: \Transaction.date, order: .reverse) private var rows: [Transaction]

    enum SaveState: Equatable { case idle, saving, saved, failed }
    @State private var kind: Kind = .spent
    @State private var amountText = ""
    @State private var category = "Food"
    @State private var note = ""
    @State private var from = ""
    @State private var date = Date.now
    @State private var error: String?
    @State private var state: SaveState = .idle
    @State private var loaded = false

    private var editing: Entry? { if case .edit(let e) = request { e } else { nil } }

    var body: some View {
        let t = Theme.current(scheme)
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("Spent").tag(Kind.spent)
                        Text("Received").tag(Kind.received)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("sheet.kind")
                    .onChange(of: kind) { _, new in
                        if !CategoryInfo.list(for: new).contains(where: { $0.name == category }) { category = CategoryInfo.list(for: new)[0].name }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$").font(.largeTitle.bold()).foregroundStyle(t.text2)
                        TextField("0.00", text: $amountText)
                            .font(.system(size: 52, weight: .regular)).monospacedDigit()
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Amount")
                            .accessibilityIdentifier("sheet.amount")
                    }
                    .listRowBackground(t.card)
                }
                .listRowBackground(Color.clear)

                if editing == nil, !recents.isEmpty {
                    Section("Recent") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recents) { r in
                                    Button { use(r) } label: {
                                        Text("\(CategoryInfo.find(r.category, kind: r.kind).icon) \(r.from.map { "\($0) · " } ?? "")\(r.note)")
                                            .font(.footnote.weight(.semibold)).lineLimit(1)
                                    }
                                    .buttonStyle(.glass)
                                    .accessibilityLabel("Reuse \(r.note)")
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Category") {
                    let list = CategoryInfo.list(for: kind)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: list.count == 6 ? 3 : 2), spacing: 10) {
                        ForEach(list, id: \.self) { info in
                            let on = category == info.name
                            Button { category = info.name } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: info.symbol).font(.title3)
                                    Text(info.name).font(.caption.weight(on ? .bold : .regular)).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .foregroundStyle(on ? t.onInk : t.text)
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(on ? t.ink : t.card, in: .rect(cornerRadius: 22))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(info.name)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField(kind == .spent ? "What was it for?" : "What's it for? (e.g. Weekly allowance)", text: $note)
                        .accessibilityIdentifier("sheet.note")
                    if kind == .received {
                        TextField("From (e.g. Mum)", text: $from).textContentType(.name)
                            .accessibilityIdentifier("sheet.from")
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                .listRowBackground(t.card)

                if let error {
                    Text(error).font(.subheadline.bold()).foregroundStyle(t.danger).frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("sheet.error")
                }

                if editing != nil {
                    Button("Delete", role: .destructive, action: delete)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("sheet.delete")
                }
            }
            .scrollContentBackground(.hidden)
            .background(t.bg.ignoresSafeArea())
            .navigationTitle(editing == nil ? (kind == .spent ? "New expense" : "Money in") : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    HStack(spacing: 8) {
                        switch state {
                        case .saving: ProgressView().tint(.white); Text("Saving…")
                        case .saved: Image(systemName: "checkmark.circle.fill"); Text("Saved")
                        case .failed: Image(systemName: "exclamationmark.circle.fill"); Text("Couldn’t save")
                        case .idle: Image(systemName: "plus"); Text(editing == nil ? (kind == .spent ? "Add expense" : "Add money in") : "Save changes")
                        }
                    }
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 20)
                    .foregroundStyle(.white)
                    .background(Color(hex: "#B94E30"), in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(SoftPressStyle())
                .disabled(state == .saving || state == .saved)
                .padding(.horizontal, 20).padding(.bottom, 8)
                .accessibilityIdentifier("sheet.save")
            }
            .sensoryFeedback(.success, trigger: state == .saved)
            .sensoryFeedback(.error, trigger: error)
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    private var recents: [Entry] { ActivityQuery.recents(rows.map(\.entry), kind: kind) }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch request {
        case .add(let k, let c):
            kind = k
            category = c ?? CategoryInfo.list(for: k)[0].name
        case .edit(let e):
            kind = e.kind
            amountText = "\(e.amount)"
            category = e.category
            note = e.note
            from = e.from ?? ""
            date = e.date
        }
    }

    private func use(_ r: Entry) {
        amountText = "\(r.amount)"
        category = r.category
        note = r.note
        from = r.from ?? ""
    }

    private func save() {
        guard let rounded = AmountParser.parse(amountText) else {
            error = "Enter an amount greater than zero, like 12.50."; return
        }
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { error = "Add a short description."; return }
        error = nil
        let sender = from.trimmingCharacters(in: .whitespaces)
        let entry = Entry(id: editing?.id ?? UUID(), kind: kind, amount: rounded, category: category, note: trimmed,
                          from: kind == .received && !sender.isEmpty ? sender : nil, date: date, isSample: editing?.isSample ?? false)
        state = .saving
        do {
            if editing != nil { try store.update(id: entry.id, with: entry) } else { try store.add(entry) }
            stash.play(kind == .spent ? .counting : .saving)
            state = .saved
            Task { try? await Task.sleep(for: .milliseconds(650)); dismiss() }
        } catch {
            state = .failed
            self.error = "Your device storage couldn’t be updated. Please try again."
            Task { try? await Task.sleep(for: .seconds(1.6)); if state == .failed { state = .idle } }
        }
    }

    private func delete() {
        guard let e = editing else { return }
        do { try onDelete(e); dismiss() }
        catch { self.error = "Your device storage couldn’t be updated. Please try again." }
    }
}
