import SwiftUI
import UIKit
import CoreLocation
import WeatherKit

struct DashboardView: View {
    // MARK: - Name stuff
    @AppStorage(userNameKey) private var userName: String = ""
    @State private var showNamePrompt = false

    // MARK: - Calendar State
    @State private var dailyRatings: [Date: Int] = [:]
    @State private var todayRating: Int? = nil
    @State private var selectedDate: IdentifiableDate?

    // MARK: - Todo State
    @State private var todoItems: [TodoItem] = []
    @AppStorage("todoGoal") private var todoGoal: Int = 10
    @State private var newItemTitle: String = ""

    // MARK: - Weather
    @StateObject private var weatherVM = WeatherViewModel()

    // MARK: - Safe Area Inset
    private var safeAreaTop: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
    }

    var bdy: some View {
        ZStack {
            // — Gradient Background —
            ZStack {
                Color(red: 0.06, green: 0.09, blue: 0.16)
                RadialGradient(
                    colors: [Color(red: 0.082, green: 0.082, blue: 0.149), Color.clear],
                    center: UnitPoint(x: 0.4, y: 0.2), startRadius: 0, endRadius: 200
                )
                RadialGradient(
                    colors: [Color(red: 0.110, green: 0.125, blue: 0.200), Color.clear],
                    center: UnitPoint(x: 0.8, y: 0.0), startRadius: 0, endRadius: 180
                )
                RadialGradient(
                    colors: [Color(red: 0.067, green: 0.067, blue: 0.122), Color.clear],
                    center: UnitPoint(x: 0.0, y: 0.5), startRadius: 0, endRadius: 160
                )
                RadialGradient(
                    colors: [Color(red: 0.098, green: 0.098, blue: 0.180), Color.clear],
                    center: UnitPoint(x: 0.8, y: 0.5), startRadius: 0, endRadius: 190
                )
                RadialGradient(
                    colors: [Color(red: 0.086, green: 0.098, blue: 0.161), Color.clear],
                    center: UnitPoint(x: 0.0, y: 1.0), startRadius: 0, endRadius: 170
                )
                RadialGradient(
                    colors: [Color(red: 0.075, green: 0.075, blue: 0.141), Color.clear],
                    center: UnitPoint(x: 0.8, y: 1.0), startRadius: 0, endRadius: 185
                )
                RadialGradient(
                    colors: [Color(red: 0.051, green: 0.051, blue: 0.102), Color.clear],
                    center: UnitPoint(x: 0.0, y: 0.0), startRadius: 0, endRadius: 150
                )
            }
            .ignoresSafeArea(.all)

            // — Main Scroll Content —
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header & Weather
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(greeting)\(userName.isEmpty ? "" : ", \(userName)")")
                                .font(.custom("BebasNeue-Regular", size: 42))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Spacer()
                            NavigationLink(destination: SettingsView()) {
                                Image(systemName: "gearshape").imageScale(.large)
                            }
                        }
                        HStack {
                            Text("Today's Weather:")
                            if weatherVM.fetchFailed {
                                Label("Unavailable :(", systemImage: "cloud.slash")
                                    .foregroundColor(.secondary)
                            } else if let temp = weatherVM.temperature,
                                      let icon = weatherVM.symbolName {
                                Label("\(temp)°", systemImage: icon)
                            } else {
                                ProgressView()
                            }
                            Spacer()
                            Text(dateFormatter.string(from: Date()))
                                .foregroundColor(.secondary)
                        }
                        .font(.body)
                    }
                    .padding(.horizontal)

                    // Today's Rating Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Rating").font(.headline)
                        HStack {
                            Button {
                                let today = Calendar.current.startOfDay(for: Date())
                                selectedDate = IdentifiableDate(date: today)
                            } label: {
                                Text(todayRating != nil ? ratingLabel(todayRating!) : "Good")
                                    .font(.body)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(todayRating != nil ? colorForRating(todayRating) : Color.blue)
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }
                            Text("Tap to update")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .padding(.horizontal)

                    // To-Do Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("To-Do").font(.headline)
                        HStack {
                            TextField("New item…", text: $newItemTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button(action: addNewItem) {
                                Image(systemName: "plus.circle.fill").imageScale(.medium).foregroundColor(.blue)
                            }
                            .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(todoItems.prefix(5)) { item in
                                HStack {
                                    Image(systemName: item.isComplete ? "checkmark.square.fill" : "square")
                                        .foregroundColor(item.isComplete ? .green : .gray)
                                    Text(item.title)
                                        .strikethrough(item.isComplete)
                                        .lineLimit(1)
                                        .font(.body)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        toggleTodo(item)
                                    }
                                }
                            }
                            if todoItems.count > 5 {
                                Text("+ \(todoItems.count - 5) more").font(.caption2).foregroundColor(.secondary)
                            }
                            if todoItems.isEmpty {
                                Text("No todos yet").font(.caption).foregroundColor(.secondary).italic()
                            }
                        }
                        FluidProgressBar(progress: CGFloat(completedTodoCount) / CGFloat(max(todoGoal, 1)))
                        Text("Done: \(completedTodoCount)/\(todoGoal)").font(.caption).foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .padding(.horizontal)

                    // This Week Progress
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This Week").font(.headline)
                        WeekProgressBar()
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .padding(.horizontal)

                    Spacer(minLength: 50)
                }
                .padding(.top, safeAreaTop)  // Push content below notch
                .frame(minHeight: UIScreen.main.bounds.height)
            }
        }
        .navigationBarHidden(true) // Hide any nav bar background
        // Modifiers inside body
        .sheet(item: $selectedDate) { identifiableDate in
            TodayRatingSheet(
                date: identifiableDate.date,
                currentRating: todayRating ?? 3
            ) { rating in
                let today = Calendar.current.startOfDay(for: Date())
                dailyRatings[today] = rating
                todayRating = rating
                saveCalendarData()
            }
        }
        .sheet(isPresented: $showNamePrompt) {
            VStack(spacing: 20) {
                Text("Welcome!").font(.title2).bold()
                Text("What's your name?").font(.body)
                TextField("Your name", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                Button("Continue") { showNamePrompt = false }
                    .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                Spacer()
            }
            .padding()
        }
        .onAppear {
            if userName.trimmingCharacters(in: .whitespaces).isEmpty {
                showNamePrompt = true
            }
            weatherVM.fetchWeather()
            loadCalendarData()
            loadTodoData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .todosReset)) { _ in
            loadTodoData()
        }
        .onChange(of: todoItems) { _ in
            saveTodoData()
        }
    }

    // MARK: - Helpers & Private
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<18: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private func WeekProgressBar() -> some View {
        HStack(spacing: 4) {
            ForEach(0..<7) { dayIndex in
                let dayDate = Calendar.current.date(byAdding: .day, value: dayIndex - 6, to: Date()) ?? Date()
                let rating = dailyRatings[Calendar.current.startOfDay(for: dayDate)]
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorForRating(rating))
                    .frame(height: 24)
                    .overlay(
                        Text(String(Calendar.current.component(.weekday, from: dayDate)).prefix(1))
                            .font(.caption2)
                            .foregroundColor(.white)
                            .opacity(0.8)
                    )
            }
        }
    }

    private func colorForRating(_ rating: Int?) -> Color {
        guard let r = rating else { return Color.gray.opacity(0.3) }
        let palette: [Color] = [
            Color(red: 0.31, green: 0.18, blue: 0.45),
            Color(red: 0.27, green: 0.36, blue: 0.70),
            Color(red: 0.45, green: 0.61, blue: 0.86),
            Color(red: 0.74, green: 0.72, blue: 0.86),
            Color(red: 0.72, green: 0.91, blue: 0.74),
            Color(red: 0.60, green: 0.84, blue: 0.56),
            Color(red: 0.38, green: 0.75, blue: 0.40)
        ]
        return r < palette.count ? palette[r] : Color.gray
    }

    private func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 0: return "Terrible"
        case 1: return "Bad"
        case 2: return "Meh"
        case 3: return "Alright"
        case 4: return "Good"
        case 5: return "Great"
        case 6: return "Awesome"
        default: return "Unknown"
        }
    }

    private var completedTodoCount: Int { todoItems.filter { $0.isComplete }.count }

    private func loadCalendarData() {
        if let data = UserDefaults.standard.data(forKey: "dailyRatings"),
           let dict = try? JSONDecoder().decode([String: Int].self, from: data) {
            dailyRatings = dict.reduce(into: [:]) { res, kv in
                if let d = ISO8601DateFormatter().date(from: kv.key) {
                    res[d] = kv.value
                }
            }
        }
        let today = Calendar.current.startOfDay(for: Date())
        todayRating = dailyRatings[today]
    }

    private func saveCalendarData() {
        let dict = dailyRatings.mapKeys { $0.ISO8601Format() }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: "dailyRatings")
        }
    }

    private func loadTodoData() {
        if let data = UserDefaults.standard.data(forKey: "todoItems"),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            todoItems = decoded
        } else {
            todoItems = []
        }
    }

    private func saveTodoData() {
        if let data = try? JSONEncoder().encode(todoItems) {
            UserDefaults.standard.set(data, forKey: "todoItems")
        }
    }

    private func addNewItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        todoItems.append(TodoItem(id: UUID(), title: title, isComplete: false))
        newItemTitle = ""
    }

    private func toggleTodo(_ item: TodoItem) {
        guard let idx = todoItems.firstIndex(of: item) else { return }
        todoItems[idx].isComplete.toggle()
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d/yy"
        return f
    }()
}

// MARK: — FluidProgressBar
struct FluidProgressBar: View {
    var progress: CGFloat
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .frame(width: geo.size.width * progress)
                    .animation(.easeInOut(duration: 0.6), value: progress)
            }
        }
        .frame(height: 20)
    }
}

// MARK: — TodayRatingSheet
struct TodayRatingSheet: View {
    let date: Date
    @State private var rating: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) var dismiss

    init(date: Date, currentRating: Int, onSave: @escaping (Int) -> Void) {
        self.date = date
        self._rating = State(initialValue: currentRating)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Rate Today").font(.title2).bold()
            Text(ratingLabel(rating)).font(.headline)
            Slider(
                value: Binding(
                    get: { Double(rating) },
                    set: { rating = Int($0) }
                ), in: 0...6, step: 1
            )
            .padding(.horizontal)
            HStack { Text("Terrible"); Spacer(); Text("Awesome") }
                .font(.caption2)
                .padding(.horizontal)
            Button("Done") {
                onSave(rating)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 16)
            Spacer()
        }
        .padding()
    }

    private func ratingLabel(_ val: Int) -> String {
        switch val {
        case 0: return "Terrible"
        case 1: return "Bad"
        case 2: return "Meh"
        case 3: return "Alright"
        case 4: return "Good"
        case 5: return "Great"
        case 6: return "Awesome"
        default: return "Unknown"
        }
    }
}

// MARK: — Dictionary Extension
fileprivate extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        reduce(into: [:]) { res, entry in
            res[transform(entry.key)] = entry.value
        }
    }
}
