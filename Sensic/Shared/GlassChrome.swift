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
// MARK: - SensicGlassCircleButton
// ─────────────────────────────────────────────

struct SensicGlassCircleButton: View {
    let systemName: String
    /// When true, icon turns white; circle stays Navy + glass (no fill swap).
    var isActive: Bool = false
    var iconColor: Color = Color("MainPurple")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? .white : iconColor)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(Color("Navy"))
                }
                .glassEffect(in: .circle)
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

// ─────────────────────────────────────────────
// MARK: - EnterNameGlassAlert
// ─────────────────────────────────────────────

struct EnterNameGlassAlert: View {
    @Binding var title: String
    let onSave: () -> Void
    let onCancel: () -> Void

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 22) {
            Text("Enter New Name")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            TextField("", text: $title, prompt: Text("Punisher").foregroundStyle(.white.opacity(0.45)))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            HStack(spacing: 14) {
                glassPillButton("Cancel", action: onCancel)
                glassPillButton("Save", action: onSave)
                    .opacity(canSave ? 1 : 0.45)
                    .disabled(!canSave)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .frame(maxWidth: 360)
        .glassEffect(in: .rect(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }

    private func glassPillButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
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
