//
//  ContentView.swift
//  Mindscape
//
//  Created by Luca DiGrigoli on 6/16/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                CalendarView()
                    .tag(0)
                MindscapesView()
                    .tag(1)
                FlowView()
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .navigationBarTitle(displayTitle(), displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Only show the gear on the Mindscapes page
                    if selectedTab == 1 {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                                .imageScale(.large)
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func displayTitle() -> String {
        switch selectedTab {
        case 0: return "Calendar"
        case 1: return "Mindscapes"
        case 2: return "Flow"
        default: return ""
        }
    }
}
