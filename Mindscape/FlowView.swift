//
//  FlowView.swift
//  Mindscape
//
//  Created by Luca DiGrigoli on 6/16/25.
//

import SwiftUI
import UIKit
import UserNotifications

// MARK: - Shared Utilities

/// Formats a TimeInterval as H:MM:SS or MM:SS
func timeString(from time: TimeInterval) -> String {
    let hours = Int(time) / 3600
    let minutes = (Int(time) % 3600) / 60
    let seconds = Int(time) % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct FlowView: View {
    // MARK: - Timer Settings
    @State private var flowDuration: TimeInterval = 45 * 60
    @State private var breakDuration: TimeInterval = 5 * 60 + 30
    @State private var timeRemaining: TimeInterval = 45 * 60

    // MARK: - Timer Control
    @State private var isRunning = false
    @State private var isFlowPhase = true
    @State private var setsRemaining = 4
    @State private var showPhaseLabel = false

    @State private var editingFlow = false
    @State private var editingBreak = false

    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 40) {
                // Safe-area spacer to avoid top clipping
                Color.clear.frame(height: 1)
                    .padding(.top)

                // MARK: - Circular Timer
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 20)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(isFlowPhase ? Color.blue : Color.green,
                                style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progress)

                    VStack {
                        if showPhaseLabel {
                            Text(isFlowPhase ? "BREAK" : "FLOW")
                                .font(.title)
                                .bold()
                                .foregroundColor(.white)
                        } else {
                            Text(timeString(from: timeRemaining))
                                .font(.largeTitle)
                                .monospacedDigit()
                                .bold()
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: 250, height: 250)

                // MARK: - Pips
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < setsRemaining ? Color.primary : Color.secondary.opacity(0.2))
                            .frame(width: 12, height: 12)
                    }
                }

                // MARK: - Duration Setters
                VStack(spacing: 16) {
                    VStack(spacing: 16) {
                        DurationPicker(label: "Flow", time: $flowDuration, isEditing: $editingFlow)
                        DurationPicker(label: "Break", time: $breakDuration, isEditing: $editingBreak)
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .padding(.horizontal)
                }

                // MARK: - Start/Stop Button
                Button(action: handleTap) {
                    Text(isRunning ? "Pause" : (showPhaseLabel ? "Start Next" : "Start"))
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isRunning ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)

                // Bottom padding for safe scrolling
                Color.clear.frame(height: 100)
            }
        }
        .onAppear {
            requestNotificationPermission()
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            tick()
        }
        .onChange(of: flowDuration) { newValue in
            // Update timeRemaining if we're in flow phase and not currently running
            if isFlowPhase && !isRunning {
                timeRemaining = newValue
            }
        }
        .onChange(of: breakDuration) { newValue in
            // Update timeRemaining if we're in break phase and not currently running
            if !isFlowPhase && !isRunning {
                timeRemaining = newValue
            }
        }
    }

    // MARK: - Computed Properties
    private var progress: Double {
        let duration = isFlowPhase ? flowDuration : breakDuration
        return max(0, min(1, 1.0 - (timeRemaining / max(duration, 1)))) // clamp & avoid div-by-zero
    }

    // MARK: - Logic Functions
    private func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            isRunning = false
            showPhaseLabel = true
            if isFlowPhase {
                setsRemaining = max(0, setsRemaining - 1)
            }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            sendPhaseNotification(isFlow: isFlowPhase)
        }
    }

    private func handleTap() {
        let buttonTap = UIImpactFeedbackGenerator(style: .light)
        buttonTap.impactOccurred()

        if showPhaseLabel {
            isFlowPhase.toggle()
            timeRemaining = isFlowPhase ? flowDuration : breakDuration
            showPhaseLabel = false
        } else {
            if !isRunning && timeRemaining <= 0 {
                timeRemaining = isFlowPhase ? flowDuration : breakDuration
            }
            isRunning.toggle()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            if !granted {
                print("Notifications not granted.")
            }
        }
    }

    private func sendPhaseNotification(isFlow: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isFlow ? "Nice flow!" : "Your break is done!"
        content.body = isFlow ? "Now let's take a break." : "Let's flow again."
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Duration Picker Subview
struct DurationPicker: View {
    var label: String
    @Binding var time: TimeInterval
    @Binding var isEditing: Bool

    private var hours: Int { Int(time) / 3600 }
    private var minutes: Int { (Int(time) % 3600) / 60 }
    private var seconds: Int { Int(time) % 60 }

    var body: some View {
        VStack(alignment: .leading) {
            Button(action: {
                let pickerTap = UIImpactFeedbackGenerator(style: .light)
                pickerTap.impactOccurred()
                isEditing.toggle()
            }) {
                HStack {
                    Text("\(label) Duration")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(timeString(from: time)) // uses shared helper
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isEditing ? 180 : 0))
                        .animation(.easeInOut, value: isEditing)
                }
            }

            if isEditing {
                HStack {
                    Picker("Hours", selection: Binding(
                        get: { self.hours },
                        set: { newHours in
                            self.time = TimeInterval(newHours * 3600 + self.minutes * 60 + self.seconds)
                        })) {
                            ForEach(0..<6, id: \.self) { hour in
                                Text("\(hour) hr").tag(hour)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 100)
                        .clipped()

                    Picker("Minutes", selection: Binding(
                        get: { self.minutes },
                        set: { newMinutes in
                            self.time = TimeInterval(self.hours * 3600 + newMinutes * 60 + self.seconds)
                        })) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute) min").tag(minute)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 100)
                        .clipped()

                    Picker("Seconds", selection: Binding(
                        get: { self.seconds },
                        set: { newSeconds in
                            self.time = TimeInterval(self.hours * 3600 + self.minutes * 60 + newSeconds)
                        })) {
                            ForEach(0..<60, id: \.self) { second in
                                Text("\(second) sec").tag(second)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 100)
                        .clipped()
                }
            }
        }
        .padding(.horizontal)
    }
}
