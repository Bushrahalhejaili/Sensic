//
//  RenameRecordingSheet.swift
//  Sensic
//

import SwiftUI

struct RenameRecordingSheet: View {
    let piece: Piece
    @Bindable var viewModel: RecordingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var showEmptyError = false

    var body: some View {
        NavigationStack {
            ZStack {
                SensicColors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recording name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SensicColors.secondaryText)

                    TextField("Name", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(SensicColors.panelNavy)
                        )

                    if showEmptyError {
                        Text("Name cannot be empty")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(SensicColors.accentRed)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Rename")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SensicColors.accentPurple)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.renamePiece(id: piece.id, title: title) {
                            dismiss()
                        } else {
                            showEmptyError = true
                        }
                    }
                    .foregroundStyle(SensicColors.accentPurple)
                }
            }
            .onAppear {
                title = piece.title
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
