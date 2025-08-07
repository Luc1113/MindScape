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
                    .ignoresSafeArea(.all)  // ← here
                DashboardView()
                    .tag(1)
                    .ignoresSafeArea(.all)  // ← here
                FlowView()
                    .tag(2)
                    .ignoresSafeArea(.all)  // ← here
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea(.all)     // ← and/or here
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .ignoresSafeArea(.all)         // ← and/or here
    }
}

