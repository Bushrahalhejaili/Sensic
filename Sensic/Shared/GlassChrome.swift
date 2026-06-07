//
//  GlassChrome.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 31/05/2026.
//
//  Shared glass-style chrome widgets used across the Creation,
//  Home, and Recordings pages. Naming convention: any new shared
//  visual primitive in this style goes here.
//



//
//  GlassChrome.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 31/05/2026.
//
//  Shared glass-style chrome widgets used across the Creation,
//  Home, and Recordings pages. Naming convention: any new shared
//  visual primitive in this style goes here.
//

import SwiftUI

// ─────────────────────────────────────────────
// MARK: - Glass shine (shared rim)
// ─────────────────────────────────────────────

enum SensicGlassChrome {
    /// Angular gradient stroke shared by circle buttons and
    /// capsule controls (HapticSettingsCard, CreationView).
    static var glassShineGradient: AngularGradient {
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

// ─────────────────────────────────────────────
// MARK: - SensicGlassCircleButton
// ─────────────────────────────────────────────

struct SensicGlassCircleButton: View {
    let systemName: String
    var iconSize: CGFloat = 16
    var iconColor: Color = Color("MainPurple")
    /// When true, icon turns white and fill becomes MainPurple.
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isActive ? .white : iconColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isActive
                              ? Color("MainPurple")
                              : Color("Navy").opacity(0.95))
                        .overlay(
                            Circle().strokeBorder(
                                SensicGlassChrome.glassShineGradient,
                                lineWidth: 0.4
                            )
                        )
                        .glassEffect(.clear)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────
// MARK: - SensicGlassSegmentPicker
// ─────────────────────────────────────────────

struct SensicGlassSegmentPicker<Tab: Hashable>: View {
    let tabs: [(tab: Tab, title: String)]
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.tab) { item in
                Button(item.title) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = item.tab
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 18)
                .foregroundStyle(selection == item.tab ? .white : Color("tertiary"))
                .background {
                    if selection == item.tab {
                        Capsule().fill(Color("MainPurple"))
                    }
                }
                .clipShape(Capsule())
            }
        }
        .padding(4)
        .glassEffect(.clear.tint(.white.opacity(20)), in: .circle)
    }
}

// (SensicNameAlert previously lived here.  It's been deleted in
// favor of the native `.alert(_:isPresented:actions:message:)`
// SwiftUI modifier — on iOS 26 that already applies Liquid Glass,
// the correct backdrop, keyboard avoidance, and return-to-submit
// behavior.  Rebuilding all of that as a custom view was just
// reinventing what the system gives you for free.)



// ─────────────────────────────────────────────
// MARK: - SensicSearchBar
// ─────────────────────────────────────────────

/// Shared pill search field — frosted glass capsule (Albums + Recordings).
struct SensicSearchBar: View {
    @Binding var text: String
    /// Muted icons for sheet contexts (Add recordings, Add to album).
    var usesMutedIcons: Bool = false

    private var iconColor: Color {
        usesMutedIcons ? Color("tertiary") : .white
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(iconColor)

            TextField(
                "",
                text: $text,
                prompt: Text("Search").foregroundStyle(Color("tertiary"))
            )
            .foregroundStyle(.white)
            .autocorrectionDisabled()

            Spacer(minLength: 0)

            Image(systemName: "mic.fill")
                .foregroundStyle(iconColor)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .glassEffect(in: .capsule)
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }
}

// ─────────────────────────────────────────────
// MARK: - SensicGlassTransportBar
// ─────────────────────────────────────────────

struct SensicGlassTransportBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassEffect(in: .capsule)
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}
