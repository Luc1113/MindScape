//
//  DashboardView.swift
//  Mindscape
//

import SwiftUI
import UIKit
import CoreLocation

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

    // MARK: - AI Service (HF-backed)
    @StateObject private var aiService = AIService()
    @State private var isChatExpanded: Bool = false
    @State private var newChatMessage: String = ""

    // Greeting
    private var greetingText: String {
        greeting + (userName.isEmpty ? "" : ", \(userName)")
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {

                    // ── Header & Weather ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(greetingText)
                                .font(.custom("BebasNeue-Regular", size: 42))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .foregroundColor(.white)
                            Spacer()
                            NavigationLink(destination: SettingsView()) {
                                Image(systemName: "gearshape")
                                    .imageScale(.large)
                                    .foregroundColor(.white)
                            }
                        }
                        HStack(spacing: 12) {
                            Text("Today's Weather:")
                                .foregroundColor(.white.opacity(0.9))

                            if weatherVM.fetchFailed {
                                Label("Unavailable :(", systemImage: "icloud.slash")
                                    .foregroundColor(.secondary)
                            } else if let temp = weatherVM.temperature {
                                let icon = weatherVM.symbolName ?? "cloud.fill"
                                let safeIcon = UIImage(systemName: icon) != nil ? icon : "cloud.fill"
                                let accent = weatherAccentColor(condition: weatherVM.conditionText, symbol: safeIcon)

                                HStack(spacing: 10) {
                                    Image(systemName: safeIcon)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(accent, .white.opacity(0.85))
                                        .font(.system(size: 28, weight: .medium))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(temp)°")
                                            .font(.headline)
                                            .foregroundColor(.white.opacity(0.95))

                                        HStack(spacing: 6) {
                                            Text(weatherVM.conditionText.isEmpty ? "…" : weatherVM.conditionText)
                                            if let wind = weatherVM.windMph {
                                                Text("• Wind \(wind) mph")
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                    }
                                }
                            } else {
                                ProgressView()
                                    .tint(.white.opacity(0.9))
                            }

                            Spacer()

                            Text(dateFormatter.string(from: Date()))
                                .foregroundColor(.secondary)
                        }
                        .font(.body)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // ── Today's Rating Card ──────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Today's Rating").font(.headline)
                            Spacer()
                            Button {
                                let today = Calendar.current.startOfDay(for: Date())
                                selectedDate = IdentifiableDate(date: today)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(todayRating != nil ? ratingLabel(todayRating!) : "Rate Today")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(todayRating != nil ? colorForRating(todayRating).opacity(0.8) : Color.blue.opacity(0.8))
                                .cornerRadius(16)
                                .foregroundColor(.white)
                            }
                        }

                        // Mini mood graph using week data
                        WeekProgressBar()
                            .frame(height: 28)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(0.8).blendMode(.overlay))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .padding(.horizontal)

                    // ── To-Do Section ───────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("To-Do").font(.headline)
                            Spacer()
                            Text("\(completedTodoCount)/\(todoGoal)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Input field for new items
                        HStack {
                            TextField("New item…", text: $newItemTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit { addNewItem() }
                            Button(action: addNewItem) {
                                Image(systemName: "plus.circle.fill")
                                    .imageScale(.medium)
                                    .foregroundColor(.blue)
                            }
                            .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        // Progress bar
                        FluidProgressBar(progress: CGFloat(completedTodoCount) / CGFloat(max(todoGoal, 1)))
                            .frame(height: 10)
                            .padding(.vertical, 4)

                        // Todo items with swipeable cards
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(todoItems.prefix(5)) { item in
                                TodoItemCard(item: item, onToggle: toggleTodo, onDelete: deleteTodo)
                            }

                            if todoItems.count > 5 {
                                Text("+ \(todoItems.count - 5) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }

                            if todoItems.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No todos yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .padding(.vertical, 12)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(0.8).blendMode(.overlay))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .padding(.horizontal)

                    // ── AI Motivational Message & Chat (HF) ─────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                                .font(.title2)
                            Text("AI Coach")
                                .font(.headline)
                            Spacer()
                            if aiService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.purple)
                            } else {
                                Button(action: refreshMotivationalMessage) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.purple)
                                        .font(.caption)
                                }
                                .accessibilityLabel("Refresh AI message")
                            }
                        }

                        // Optional hint if HF is loading / errors (e.g., 503)
                        if aiService.hasError {
                            Text("The AI might be spinning up. Try again in a few seconds.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(aiService.motivationalMessage)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .animation(.easeInOut(duration: 0.3), value: aiService.motivationalMessage)

                        // Chat toggle
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isChatExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "message.fill").font(.caption)
                                Text(isChatExpanded ? "Hide Chat" : "Chat with AI")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .rotationEffect(.degrees(isChatExpanded ? 180 : 0))
                                    .animation(.easeInOut(duration: 0.3), value: isChatExpanded)
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(16)
                        }

                        // Expandable Chat
                        if isChatExpanded {
                            VStack(spacing: 12) {
                                // Messages
                                ScrollViewReader { proxy in
                                    ScrollView {
                                        LazyVStack(spacing: 8) {
                                            if aiService.chatMessages.isEmpty {
                                                Text("Start a conversation with your AI coach!")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .italic()
                                                    .padding(.vertical, 20)
                                            } else {
                                                ForEach(aiService.chatMessages) { message in
                                                    ChatBubble(message: message)
                                                        .id(message.id)
                                                }
                                            }

                                            if aiService.isChatLoading {
                                                HStack {
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                        .tint(.purple)
                                                    Text("AI is typing...")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                    .frame(maxHeight: 200)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(12)
                                    .onChange(of: aiService.chatMessages.count) { _, _ in
                                        if let lastMessage = aiService.chatMessages.last {
                                            withAnimation {
                                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                            }
                                        }
                                    }
                                }

                                // Input
                                HStack {
                                    TextField("Ask me anything...", text: $newChatMessage, axis: .vertical)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .lineLimit(3)
                                        .onSubmit { sendChatMessage() }

                                    Button(action: sendChatMessage) {
                                        Image(systemName: "paperplane.fill")
                                            .foregroundColor(.purple)
                                            .font(.system(size: 16))
                                    }
                                    .disabled(newChatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isChatLoading)
                                }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(0.8).blendMode(.overlay))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .padding(.horizontal)

                    // Spacer
                    Color.clear.frame(height: 100)
                }
            }
        }
        .navigationBarHidden(true)

        // ── Sheets ───────────────────────────────────────────────────────────────
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

        // ── On appear / data loads ──────────────────────────────────────────────
        .onAppear {
            if userName.trimmingCharacters(in: .whitespaces).isEmpty {
                showNamePrompt = true
            }
            weatherVM.fetchWeather()
            loadCalendarData()
            loadTodoData()
            aiService.testAPIConnection()     // now hits HF model endpoint
            refreshMotivationalMessage()      // uses HF under the hood
        }
        .onReceive(NotificationCenter.default.publisher(for: .todosReset)) { _ in
            loadTodoData()
        }
        .onChange(of: todoItems) { _, _ in
            saveTodoData()
        }
    }

    // MARK: - Helpers
    
    private func weatherAccentColor(condition: String, symbol: String) -> Color {
        let c = condition.lowercased()
        if c.contains("clear") { return .yellow }
        if c.contains("partly") || c.contains("sun") { return .orange }
        if c.contains("overcast") || c.contains("cloud") { return .gray }
        if c.contains("fog") { return .mint }
        if c.contains("drizzle") { return .teal }
        if c.contains("rain") || c.contains("showers") { return .blue }
        if c.contains("snow") { return .cyan }
        if c.contains("thunder") { return .purple }
        // fallback by symbol family if text is empty
        if symbol.contains("bolt") { return .purple }
        if symbol.contains("snow") { return .cyan }
        if symbol.contains("rain") { return .blue }
        if symbol.contains("sun") || symbol.contains("moon") { return .orange }
        return .gray
    }

    
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
            ForEach(0..<7, id: \.self) { dayIndex in
                let dayDate = Calendar.current.date(byAdding: .day, value: dayIndex - 6, to: Date()) ?? Date()
                let rating = dailyRatings[Calendar.current.startOfDay(for: dayDate)]
                let weekdaySymbol = Calendar.current.shortWeekdaySymbols[Calendar.current.component(.weekday, from: dayDate) - 1]

                RoundedRectangle(cornerRadius: 6)
                    .fill(colorForRating(rating))
                    .frame(height: 24)
                    .overlay(
                        Text(String(weekdaySymbol.prefix(1)))
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
        return r >= 0 && r < palette.count ? palette[r] : Color.gray
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

    private var completedTodoCount: Int {
        todoItems.filter { $0.isComplete }.count
    }

    // MARK: - Persistence
    private func loadCalendarData() {
        if let data = UserDefaults.standard.data(forKey: "dailyRatings"),
           let dict = try? JSONDecoder().decode([String: Int].self, from: data) {
            let formatter = ISO8601DateFormatter()
            dailyRatings = dict.reduce(into: [:]) { result, kv in
                if let date = formatter.date(from: kv.key) {
                    result[Calendar.current.startOfDay(for: date)] = kv.value
                }
            }
        }
        let today = Calendar.current.startOfDay(for: Date())
        todayRating = dailyRatings[today]
    }

    private func saveCalendarData() {
        let formatter = ISO8601DateFormatter()
        let dict = dailyRatings.reduce(into: [String: Int]()) { result, kv in
            result[formatter.string(from: kv.key)] = kv.value
        }
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

    // MARK: - Actions
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

    private func deleteTodo(_ item: TodoItem) {
        guard let idx = todoItems.firstIndex(of: item) else { return }
        withAnimation {
            _ = todoItems.remove(at: idx)
        }
    }

    private func refreshMotivationalMessage() {
        aiService.fetchMotivationalMessage(
            todayRating: todayRating,
            completedTodos: completedTodoCount,
            totalTodos: todoGoal
        )
    }

    private func sendChatMessage() {
        let message = newChatMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        aiService.sendChatMessage(
            message,
            todayRating: todayRating,
            completedTodos: completedTodoCount,
            totalTodos: todoGoal
        )

        newChatMessage = ""
    }

    // MARK: - Date formatting
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
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * progress)))
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

            Text(ratingLabel(rating))
                .font(.headline)
                .foregroundColor(colorForRating(rating))

            Slider(
                value: Binding(
                    get: { Double(rating) },
                    set: { rating = Int(round($0)) }
                ),
                in: 0...6,
                step: 1
            )
            .padding(.horizontal)

            HStack {
                Text("Terrible")
                Spacer()
                Text("Awesome")
            }
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

    private func colorForRating(_ rating: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.31, green: 0.18, blue: 0.45),
            Color(red: 0.27, green: 0.36, blue: 0.70),
            Color(red: 0.45, green: 0.61, blue: 0.86),
            Color(red: 0.74, green: 0.72, blue: 0.86),
            Color(red: 0.72, green: 0.91, blue: 0.74),
            Color(red: 0.60, green: 0.84, blue: 0.56),
            Color(red: 0.38, green: 0.75, blue: 0.40)
        ]
        return rating >= 0 && rating < palette.count ? palette[rating] : Color.gray
    }
}

// MARK: — TodoItemCard
struct TodoItemCard: View {
    var item: TodoItem
    var onToggle: (TodoItem) -> Void
    var onDelete: (TodoItem) -> Void

    var body: some View {
        HStack {
            // Checkbox
            Button(action: { onToggle(item) }) {
                Image(systemName: item.isComplete ? "checkmark.square.fill" : "square")
                    .foregroundColor(item.isComplete ? .green : .primary)
                    .font(.system(size: 20))
                    .frame(width: 32)
            }
            .buttonStyle(BorderlessButtonStyle())

            // Title
            Text(item.title)
                .font(.body)
                .foregroundColor(item.isComplete ? .secondary : .primary)
                .strikethrough(item.isComplete)
                .lineLimit(1)

            Spacer()

            // Delete
            Button(action: { withAnimation { onDelete(item) } }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
                    .font(.system(size: 16))
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
        )
        .cornerRadius(10)
    }
}

// MARK: — ChatBubble
struct ChatBubble: View {
    var message: ChatMessage

    var body: some View {
        HStack {
            if message.isUserMessage {
                Spacer()
                Text(message.text)
                    .padding(12)
                    .background(Color.blue.opacity(0.8), in: ChatBubbleShape(isUserMessage: true))
                    .foregroundColor(.white)
                    .font(.body)
                    .frame(maxWidth: 300, alignment: .trailing)
            } else {
                Text(message.text)
                    .padding(12)
                    .background(Color.gray.opacity(0.2), in: ChatBubbleShape(isUserMessage: false))
                    .foregroundColor(.primary)
                    .font(.body)
                    .frame(maxWidth: 300, alignment: .leading)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

// MARK: — ChatBubbleShape
struct ChatBubbleShape: Shape {
    var isUserMessage: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailWidth: CGFloat = 10
        let tailHeight: CGFloat = 20

        var path = Path()

        // Rounded rectangle
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: radius, height: radius),
            style: .continuous
        )

        // Tail
        if isUserMessage {
            var tail = Path()
            tail.move(to: CGPoint(x: rect.maxX - tailWidth, y: rect.midY))
            tail.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - tailHeight))
            tail.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + tailHeight))
            path.addPath(tail)
        } else {
            var tail = Path()
            tail.move(to: CGPoint(x: tailWidth, y: rect.midY))
            tail.addLine(to: CGPoint(x: 0, y: rect.midY - tailHeight))
            tail.addLine(to: CGPoint(x: 0, y: rect.midY + tailHeight))
            path.addPath(tail)
        }

        return path
    }
}
