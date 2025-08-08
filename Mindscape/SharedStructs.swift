//
//  SharedStructs.swift
//  Mindscape
//
//  Created by Luca DiGrigoli on 8/6/25.
//

import Foundation
import WeatherKit
import CoreLocation
import SwiftUI

struct AnimatedBackgroundView: View {
    @State private var animationOffset1: CGFloat = 0
    @State private var animationOffset2: CGFloat = 0
    @State private var animationOffset3: CGFloat = 0
    @State private var rotationAngle1: Double = 0
    @State private var rotationAngle2: Double = 0
    @State private var pulseScale1: CGFloat = 1.0
    @State private var pulseScale2: CGFloat = 1.0
    @State private var pulseOpacity1: Double = 0.6
    @State private var pulseOpacity2: Double = 0.5
    
    var body: some View {
        ZStack {
            // Deep space background color
            Color(red: 0.04, green: 0.06, blue: 0.12)
            
            // Subtle base glow
            RadialGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.2, opacity: 0.7), Color.clear],
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            
            // Fluid northern lights effects
            
            // First aurora wave
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.6, blue: 0.8, opacity: 0.5),
                    Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 0.4),
                    Color.clear
                ]),
                startPoint: UnitPoint(x: animationOffset1, y: 0.2),
                endPoint: UnitPoint(x: animationOffset1 + 0.8, y: 0.8)
            )
            .blendMode(.plusLighter)
            .rotationEffect(.degrees(20 + rotationAngle1))
            .scaleEffect(pulseScale1)
            .opacity(pulseOpacity1)
            
            // Second aurora wave
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.4, green: 0.2, blue: 0.8, opacity: 0.5),
                    Color(red: 0.5, green: 0.3, blue: 0.7, opacity: 0.4),
                    Color.clear
                ]),
                startPoint: UnitPoint(x: 0.2, y: animationOffset2),
                endPoint: UnitPoint(x: 0.8, y: animationOffset2 + 0.6)
            )
            .blendMode(.plusLighter)
            .rotationEffect(.degrees(-15 + rotationAngle2))
            .scaleEffect(pulseScale2)
            .opacity(pulseOpacity2)
            
            // Third aurora wave (green-teal)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.8, blue: 0.6, opacity: 0.4),
                    Color(red: 0.3, green: 0.7, blue: 0.5, opacity: 0.3),
                    Color.clear
                ]),
                startPoint: UnitPoint(x: animationOffset3, y: 0.8),
                endPoint: UnitPoint(x: animationOffset3 + 0.7, y: 0.3)
            )
            .blendMode(.plusLighter)
            .rotationEffect(.degrees(45 - rotationAngle1 * 0.5))
            .scaleEffect(pulseScale1 * 0.9)
            .opacity(pulseOpacity1 * 0.8)
            
            // Soft star-like highlights
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 4, height: 4)
                    .blur(radius: 2)
                    .offset(x: -100, y: -150)
                    .scaleEffect(pulseScale2 * 1.2)
                
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 6, height: 6)
                    .blur(radius: 3)
                    .offset(x: 120, y: -100)
                    .scaleEffect(pulseScale1 * 1.3)
                
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 5, height: 5)
                    .blur(radius: 2.5)
                    .offset(x: -80, y: 130)
                    .scaleEffect(pulseScale2 * 1.1)
                
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 3, height: 3)
                    .blur(radius: 1.5)
                    .offset(x: 140, y: 160)
                    .scaleEffect(pulseScale1 * 1.2)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Start fluid animations
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animationOffset1 = 0.2
                rotationAngle1 = 30
                pulseScale1 = 1.2
                pulseOpacity1 = 0.8
            }
            
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true).delay(2)) {
                animationOffset2 = 0.3
                rotationAngle2 = -25
                pulseScale2 = 1.15
                pulseOpacity2 = 0.7
            }
            
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true).delay(4)) {
                animationOffset3 = 0.25
            }
        }
    }
}

let userNameKey = "userName"

/// Wraps a `Date` so it can drive `.sheet(item:)`
struct IdentifiableDate: Identifiable, Equatable {
    let id = UUID()
    let date: Date
}
