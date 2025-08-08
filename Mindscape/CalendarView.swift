import SwiftUI

// MARK: - CalendarView

struct CalendarView: View {
    // MARK: State
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var dailyRatings: [Date: Int] = [:]
    @State private var bestDay: Date?
    @State private var worstDay: Date?
    @State private var showYearPicker: Bool = false
    @State private var selectedDate: IdentifiableDate?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Year header as tappable button (no commas)
                Button(action: { showYearPicker = true }) {
                    Text(String(selectedYear))
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                }
                .sheet(isPresented: $showYearPicker, onDismiss: loadAll) {
                    YearPicker(selectedYear: $selectedYear)
                }
                .padding(.top)

                // All 12 months
                LazyVStack(spacing: 32) {
                    ForEach(monthsInYear, id: \.self) { month in
                        VStack(alignment: .leading, spacing: 16) {
                            MonthView(
                                month: month,
                                dailyRatings: dailyRatings,
                                bestDay: bestDay,
                                worstDay: worstDay
                            ) { date in
                                selectedDate = IdentifiableDate(date: date)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
        }
        // Rating sheet
        .sheet(item: $selectedDate) { (identifiable: IdentifiableDate) in
            RatingSliderSheet(
                date: identifiable.date,
                rating: Binding(
                    get: { dailyRatings[identifiable.date] ?? 3 },
                    set: { newValue in
                        if newValue == 15, let prev = bestDay, prev != identifiable.date {
                            dailyRatings[prev] = 6
                        }
                        if newValue == -15, let prev = worstDay, prev != identifiable.date {
                            dailyRatings[prev] = 0
                        }
                        if newValue == 15 {
                            bestDay = identifiable.date
                        } else if newValue == -15 {
                            worstDay = identifiable.date
                        }
                        dailyRatings[identifiable.date] = newValue
                    }
                ),
                bestDay: $bestDay,
                worstDay: $worstDay,
                onSave: saveAll
            )
        }
        .onAppear(perform: loadAll)
        .onChange(of: selectedYear) {
            loadAll()
        }
    }

    // MARK: - Helpers

    private var monthsInYear: [Date] {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: selectedYear, month: 1))!
        return (0..<12).compactMap { cal.date(byAdding: .month, value: $0, to: start) }
    }

    private func saveAll() {
        let dict = dailyRatings.mapKeys { $0.ISO8601Format() }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: "dailyRatings")
        }
        UserDefaults.standard.set(bestDay?.ISO8601Format(), forKey: "bestDay\(selectedYear)")
        UserDefaults.standard.set(worstDay?.ISO8601Format(), forKey: "worstDay\(selectedYear)")
    }

    private func loadAll() {
        if let data = UserDefaults.standard.data(forKey: "dailyRatings"),
           let dict = try? JSONDecoder().decode([String: Int].self, from: data) {
            dailyRatings = dict.reduce(into: [Date: Int]()) { res, kv in
                if let d = ISO8601DateFormatter().date(from: kv.key) {
                    res[d] = kv.value
                }
            }
        }
        if let str = UserDefaults.standard.string(forKey: "bestDay\(selectedYear)"),
           let d = ISO8601DateFormatter().date(from: str) {
            bestDay = d
        } else {
            bestDay = nil
        }
        if let str = UserDefaults.standard.string(forKey: "worstDay\(selectedYear)"),
           let d = ISO8601DateFormatter().date(from: str) {
            worstDay = d
        } else {
            worstDay = nil
        }
    }
}


// MARK: - YearPicker

struct YearPicker: View {
    @Binding var selectedYear: Int
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("Select Year")
                .font(.headline)
                .padding()

            Picker("", selection: $selectedYear) {
                ForEach(2020...2030, id: \.self) {
                    Text(String($0)).tag($0)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .labelsHidden()
            .frame(maxHeight: 200)

            Button("Done") { dismiss() }
                .padding(.top)
        }
    }
}


// MARK: - MonthView

struct MonthView: View {
    let month: Date
    let dailyRatings: [Date: Int]
    let bestDay: Date?
    let worstDay: Date?
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthFormatter.string(from: month))
                .font(.headline)
                .foregroundColor(.primary)
            Text("Avg: \(monthAverage(month))")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(daysInMonth(month), id: \.self) { day in
                    CalendarCell(
                        day: day,
                        rating: dailyRatings[day],
                        isBest: day == bestDay,
                        isWorst: day == worstDay
                    )
                    .onTapGesture { onSelect(day) }
                }
            }
        }
    }

    private func daysInMonth(_ month: Date) -> [Date] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: month)!
        let comps = cal.dateComponents([.year, .month], from: month)
        return range.compactMap { d in
            var c = comps; c.day = d
            return cal.date(from: c)
        }
    }

    private func monthAverage(_ month: Date) -> String {
        let vals = daysInMonth(month).compactMap { dailyRatings[$0] }
        guard !vals.isEmpty else { return "—" }
        let avg = Double(vals.reduce(0, +)) / Double(vals.count)
        return String(format: "%.1f", avg)
    }
}


// MARK: - CalendarCell

struct CalendarCell: View {
    let day: Date
    let rating: Int?
    let isBest: Bool
    let isWorst: Bool

    var body: some View {
        Text(dayFormatter.string(from: day))
            .font(.caption2)
            .frame(width: 28, height: 28)
            .background(cellColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isWorst ? Color.white : .clear, lineWidth: 2)
            )
            .cornerRadius(4)
            .foregroundColor(.white)
    }

    private var cellColor: Color {
        if isBest { return Color(red: 1.0, green: 0.95, blue: 0.55) }
        if isWorst { return .black }
        guard let r = rating else { return Color.gray.opacity(0.2) }
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
}


// MARK: - RatingSliderSheet

struct RatingSliderSheet: View {
    let date: Date
    @Binding var rating: Int
    @Binding var bestDay: Date?
    @Binding var worstDay: Date?
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Rate This Day").font(.title2).bold()

            Text(ratingLabel(rating))
                .font(.headline)

            Slider(
                value: Binding(
                    get: { Double(rating) },
                    set: { new in
                        rating = Int(round(new))
                        if rating != 15, bestDay == date { bestDay = nil }
                        if rating != -15, worstDay == date { worstDay = nil }
                    }
                ),
                in: 0...6, step: 1
            )
            .padding(.horizontal)

            HStack { Text("Terrible"); Spacer(); Text("Awesome") }
                .font(.caption2)
                .padding(.horizontal)

            Divider().padding(.vertical, 8)

            HStack(spacing: 16) {
                Button("⭐ Best Day") {
                    rating = 15
                    onSave(); dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)

                Button("💀 Worst Day") {
                    rating = -15
                    onSave(); dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
            }

            Button("Done") {
                rating = rating
                onSave()
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
        case -15: return "Worst Day of \(Calendar.current.component(.year, from: date))"
        case 15:  return "Best Day of \(Calendar.current.component(.year, from: date))"
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

// MARK: - Utilities

fileprivate extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        reduce(into: [T: Value]()) { res, entry in
            res[transform(entry.key)] = entry.value
        }
    }
}

fileprivate let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "d"
    return f
}()

fileprivate let monthFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMMM"
    return f
}()
