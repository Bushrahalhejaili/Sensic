//
//  Component.swift
//  Sensic
//
//  Created by شهد عبدالله القحطاني on 01/12/1447 AH.
//

import SwiftUI

// ─────────────────────────────────────────────
// MARK: - SessionRow
// ─────────────────────────────────────────────

struct SessionRow: View {
    let session: PracticeSession
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color("MainPurple").opacity(0.12))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "music.note").foregroundStyle(Color("MainPurple")))

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title).font(.subheadline.weight(.medium)).foregroundStyle(.white)
                Text("\(session.noteEvents.count) notes · \(Int(session.durationSeconds))s")
                    .font(.caption).foregroundStyle(Color("tertiary"))
            }

            Spacer()

            Text("\(Int(session.accuracy * 100))%")
                .font(.caption.bold()).foregroundStyle(Color("MainPurple"))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color("MainPurple").opacity(0.12)).clipShape(Capsule())

            Button(action: onDelete) {
                Image(systemName: "trash").font(.system(size: 14))
                    .foregroundStyle(Color("tertiary"))
            }
        }
        .padding(14)
        .background(Color("SpaceBlue"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}

// ─────────────────────────────────────────────
// MARK: - StatCard
// ─────────────────────────────────────────────

struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(Color("tertiary"))
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color("SpaceBlue"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}
