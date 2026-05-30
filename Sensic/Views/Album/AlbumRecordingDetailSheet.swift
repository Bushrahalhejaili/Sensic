//
//  AlbumRecordingDetailSheet.swift
//  Sensic
//

import SwiftUI

struct AlbumRecordingDetailSheet: View {
    let recording: RecordingItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    detailRow(label: "Title", value: recording.title)
                    detailRow(label: "Date", value: recording.date)
                    detailRow(label: "Duration", value: recording.duration)

                    Spacer()
                }
                .padding(20)
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color("MainPurple"))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color("tertiary"))

            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color("SpaceBlue"))
        )
    }
}


