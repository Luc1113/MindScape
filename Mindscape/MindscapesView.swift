import SwiftUI

// MARK: — Model

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isComplete: Bool
}

// MARK: — MindscapesView

struct MindscapesView: View {
    @State private var items: [TodoItem] = Self.loadItems()
    @AppStorage("todoGoal") private var goal: Int = 0
    @State private var newItemTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Add new item
            HStack {
                TextField("New item…", text: $newItemTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: addNewItem) {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                }
                .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            // To-do list
            List {
                ForEach(items) { item in
                    Button(action: { toggle(item) }) {
                        HStack {
                            Image(systemName: item.isComplete ? "checkmark.square" : "square")
                            Text(item.title)
                                .strikethrough(item.isComplete, color: .primary)
                        }
                    }
                }

                // Fluid fill progress bar
                FluidProgressBar(progress: CGFloat(completedCount) / CGFloat(max(goal, 1)))
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Textual progress
                Text("\(completedCount) of \(goal) done")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
            // Persist changes whenever items change
            .onChange(of: items) { _ in
                Self.saveItems(items)
            }
            // Listen for the reset notification to clear in-memory list
            .onReceive(NotificationCenter.default.publisher(for: .todosReset)) { _ in
                items = []
            }
            .navigationTitle("Mindscapes")
        }
    }

    // MARK: — Computed

    private var completedCount: Int {
        items.filter { $0.isComplete }.count
    }

    // MARK: — Actions

    private func addNewItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        items.append(TodoItem(id: UUID(), title: title, isComplete: false))
        newItemTitle = ""
    }

    private func toggle(_ item: TodoItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        items[idx].isComplete.toggle()
    }

    // MARK: — Persistence

    private static let itemsKey = "todoItems"

    private static func loadItems() -> [TodoItem] {
        guard
            let data = UserDefaults.standard.data(forKey: itemsKey),
            let decoded = try? JSONDecoder().decode([TodoItem].self, from: data)
        else {
            return []
        }
        return decoded
    }

    private static func saveItems(_ items: [TodoItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: itemsKey)
        }
    }
}

struct MindscapesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MindscapesView()
        }
    }
}
