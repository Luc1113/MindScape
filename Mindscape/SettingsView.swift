import SwiftUI

// Make sure this lives somewhere accessible in your project
extension Notification.Name {
    static let todosReset = Notification.Name("todosReset")
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(userNameKey) private var userName: String = ""
    
    // Calendar reset state
    @State private var showResetCalendar = false
    
    // Todos goal & reset
    @AppStorage("todoGoal") private var goal: Int = 0
    @State private var showResetTodos = false
    
    var body: some View {
        Form {
            // Calendar section
            Section(header: Text("Calendar")) {
                let headerText = Text("Reset All Calendar Ratings")
                Button(role: .destructive) {
                    showResetCalendar = true
                } label: {
                    headerText
                }
            }
            
            //Name Section
            Section(header: Text("Profile")) {
                TextField("Your Name", text: $userName)
            }
            
            // Todos section
            Section(header: Text("Todos")) {
                Stepper("Goal: \(goal)", value: $goal, in: 0...100)
                
                Button(role: .destructive) {
                    showResetTodos = true
                } label: {
                    Text("Reset All Todos")
                }
            }
            
            // About / Credits
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mindscapes Test Version 0.1")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Thank you to the following people:")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    Text("• Colin J. Dowd – Testing/Suggestions")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("• Alvaro Mijangos Guzmán – Testing/Suggestions")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        
        // Calendar reset alert
        .alert("Reset All Ratings?", isPresented: $showResetCalendar) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                UserDefaults.standard.removeObject(forKey: "dailyRatings")
                for year in 2020...2030 {
                    UserDefaults.standard.removeObject(forKey: "bestDay\(year)")
                    UserDefaults.standard.removeObject(forKey: "worstDay\(year)")
                }
                exit(0)
            }
        } message: {
            Text("This will erase all calendar ratings and best/worst days for all years. The app will need to restart.")
        }
        
        // Todos reset alert
        .alert("Reset All Todos?", isPresented: $showResetTodos) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                UserDefaults.standard.removeObject(forKey: "todoItems")
                NotificationCenter.default.post(name: .todosReset, object: nil)
            }
        } message: {
            Text("This will remove all to-do items and their completion states.")
        }
    }
}
