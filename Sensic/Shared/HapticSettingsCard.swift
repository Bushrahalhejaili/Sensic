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

    // Card dimensions — locked to match the Figma frame.
    private static let cardWidth:  CGFloat = 366
    private static let cardHeight: CGFloat = 170
    private static let cardCornerRadius: CGFloat = 28

    var body: some View {
        ZStack(alignment: .topLeading) {

            // MARK: Background
            // Solid Navy, no liquid glass. Rounded corners match the
            // Figma frame.
            RoundedRectangle(
                cornerRadius: Self.cardCornerRadius,
                style: .continuous
            )
            .fill(Color("Navy"))

            // MARK: Left column — Intensity + Sharpness sliders
            //
            // The column sits 17 from the card's left edge (slider
            // anchor) and 15 from the top. The label text uses a
            // 2pt leading inset so it sits at x=19 from card edge,
            // 2pt to the right of the slider — matches the Figma.
            VStack(alignment: .leading, spacing: 0) {
                Text("Haptic intensity")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .padding(.leading, 2)

                Slider(value: $settings.intensity)
                    .tint(Color("MainPurple"))
                    .frame(width: 172)
                    .padding(.top, 10)

                Text("Haptic Sharpness")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .padding(.leading, 2)
                    .padding(.top, 12)

                Slider(value: $settings.sharpness)
                    .tint(Color("MainPurple"))
                    .frame(width: 172)
                    .padding(.top, 10)
            }
            .padding(.leading, 17)
            .padding(.top, 15)

            // MARK: Vertical divider
            //
            // 1pt-wide line, 150 tall, anchored 10pt from top and
            // 10pt from bottom of the card. Positioned at x=217 so
            // it sits equidistant between the left column's right
            // edge (slider end at 189) and the right column's left
            // edge (button start at 246): (189+246)/2 ≈ 217.
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 150)
                .offset(x: 217, y: 10)

            // MARK: Right column — Style label + Smooth / Punchy
            //
            // Spans the full card width so children can right-align
            // independently — the "Haptic style" label sits 17 from
            // the right edge, while the two buttons sit 24 from the
            // right edge. Both alignments share the same trailing
            // anchor; the per-child .padding(.trailing, …) is what
            // creates the 7pt offset between text and buttons.
            VStack(alignment: .trailing, spacing: 0) {
                Text("Haptic style")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .padding(.trailing, 17)

                styleButton("Smooth", style: .smooth)
                    .padding(.top, 11)
                    .padding(.trailing, 24)

                styleButton("Punchy", style: .punchy)
                    .padding(.top, 14)
                    .padding(.trailing, 24)
            }
            .frame(width: Self.cardWidth, alignment: .trailing)
            .padding(.top, 15)
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
    }

    // MARK: - Style button
    //
    // 96×44 capsule with the same glass treatment as the circular
    // buttons in CreationView: Navy fill by default, MainPurple
    // when selected, a thin angular-gradient stroke for the rim,
    // and `.glassEffect(.clear)` for the liquid-glass shine. Same
    // spring-tinted animation on color change so the swap feels
    // smooth rather than abrupt.

    private func styleButton(_ title: String, style: HapticStyle) -> some View {
        let selected = settings.style == style
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.style = style
            }
        } label: {
            Text(title)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 96, height: 44)
                .background(
                    Capsule()
                        .fill(selected
                              ? Color("MainPurple")
                              : Color("Navy").opacity(0.95))
                        .overlay(
                            Capsule().strokeBorder(
                                glassShineGradient,
                                lineWidth: 0.4
                            )
                        )
                        .glassEffect(.clear)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Shared angular gradient for the glass rim on the style
    /// buttons. Copied from CreationView's `glassShineGradient` so
    /// the two surfaces feel like the same family.
    private var glassShineGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(0.4),
                Color.white.opacity(0.6),
                Color.black.opacity(0.2),
                Color.white.opacity(0.9),
                Color.black.opacity(0.2),
                Color.black.opacity(0.4)
            ]),
            center: .center
        )
    }
}
