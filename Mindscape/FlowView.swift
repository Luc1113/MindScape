//
//  FlowView.swift
//  Mindscape
//
//  Created by Luca DiGrigoli on 6/16/25.
//

import SwiftUI
import UIKit
import UserNotifications

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
        VStack(spacing: 40) {
            // MARK: - Circular Timer
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 20)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(isFlowPhase ? Color.blue : Color.green, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                VStack {
                    if showPhaseLabel {
                        Text(isFlowPhase ? "BREAK" : "FLOW")
                            .font(.title)
                            .bold()
                    } else {
                        Text(timeString(from: timeRemaining))
                            .font(.largeTitle)
                            .monospacedDigit()
                            .bold()
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
                DurationPicker(label: "Flow", time: $flowDuration, isEditing: $editingFlow)
                DurationPicker(label: "Break", time: $breakDuration, isEditing: $editingBreak)
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
        }
        .padding()
        .onAppear {
            requestNotificationPermission()
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            tick()
        }
    }

    // MARK: - Computed Properties
    private var progress: Double {
        let duration = isFlowPhase ? flowDuration : breakDuration
        return 1.0 - (timeRemaining / duration)
    }

    // MARK: - Logic Functions
    private func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            isRunning = false
            showPhaseLabel = true
            if isFlowPhase {
                setsRemaining -= 1
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
            if !isRunning {
                timeRemaining = isFlowPhase ? flowDuration : breakDuration
            }
            isRunning.toggle()
        }
    }

    private func timeString(from time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
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

    var hours: Int {
        Int(time) / 3600
    }

    var minutes: Int {
        (Int(time) % 3600) / 60
    }

    var seconds: Int {
        Int(time) % 60
    }

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
                    Spacer()
                    Text(timeString(from: time))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
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
                            ForEach(0..<6) { hour in
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
                            ForEach(0..<60) { minute in
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
                            ForEach(0..<60) { second in
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

    private func timeString(from time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
