import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackgroundView().ignoresSafeArea()   // <- fixed background

                TabView(selection: $selectedTab) {
                    CalendarView()
                        .tag(0)

                    DashboardView()   // contains the gear NavigationLink
                        .tag(1)

                    FlowView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
    }
}
