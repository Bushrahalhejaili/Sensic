//
//  HapticSettingsCard.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 31/05/2026.
//
//  Shared haptic settings panel — used by both Practice mode
//  (always visible inside the workspace) and Record mode
//  (presented behind a button trigger). Binds to HapticSettings
//  so changes in one mode appear immediately in the other.
//

import SwiftUI

struct HapticSettingsCard: View {
    @ObservedObject var settings: HapticSettings

    var body: some View {
        HStack(spacing: 0) {

            
            VStack(alignment: .leading, spacing: 18) {
                hapticSlider(label: "Haptic Intensity", value: $settings.intensity)
                hapticSlider(label: "Haptic Sharpness", value: $settings.sharpness)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)
                .padding(.vertical, 14)

            
            VStack(alignment: .center, spacing: 10) {
                Text("Haptic style")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                styleButton("Smooth", style: .smooth)
                styleButton("Punchy", style: .punchy)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
            .frame(width: 130)
        }
        .background(Color(red: 0.043, green: 0.075, blue: 0.169))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .glassEffect(in: .rect(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.55), location: 0.0),
                            .init(color: Color.white.opacity(0.20), location: 0.3),
                            .init(color: Color.white.opacity(0.0),  location: 0.5),
                            .init(color: Color(red:0.043,green:0.075,blue:0.169).opacity(0.3), location: 0.7),
                            .init(color: Color(red:0.043,green:0.075,blue:0.169).opacity(0.55), location: 1.0)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }

    private func hapticSlider(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)


            Slider(value: value)
                .tint(Color("MainPurple"))
        }
    }

    private func styleButton(_ title: String, style: HapticStyle) -> some View {
        let selected = settings.style == style
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.style = style
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selected
                        ? Color("MainPurple")
                        : Color(red: 0.043, green: 0.075, blue: 0.169)
                )
                .clipShape(Capsule())
                .glassEffect(in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.0),  location: 0.0),
                                    .init(color: Color.white.opacity(0.70), location: 0.5),
                                    .init(color: Color.white.opacity(0.0),  location: 1.0)
                                ],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
