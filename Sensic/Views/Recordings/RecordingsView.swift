//
//  RecordingsView.swift
//  Sensic
//

import SwiftUI

struct RecordingsView: View {
    @Bindable var store: RecordingsStore
    @Bindable var viewModel: RecordingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isHeaderCollapsed = false

    /// Collapse once scrolled past this offset; expand only below `headerExpandScrollThreshold` so the compact bar doesn’t flicker/bounce open.
    private let headerCollapseScrollThreshold: CGFloat = 24
    private let headerExpandScrollThreshold: CGFloat = 8

    private var filteredPieces: [Piece] {
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.pieces }
        return store.pieces.filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    private var sections: [RecordingSection] {
        RecordingSectionBuilder.sections(from: filteredPieces)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                RecordingsHeaderView(
                    count: filteredPieces.count,
                    collapsed: isHeaderCollapsed,
                    onBack: { dismiss() }
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, isHeaderCollapsed ? 10 : 16)
                .animation(.easeInOut(duration: 0.22), value: isHeaderCollapsed)
                .background(Color.black)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(Color("MainPurple"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else if sections.isEmpty {
                            RecordingsEmptyListState()
                        } else {
                            ForEach(sections) { section in
                                RecordingsSectionView(
                                    section: section,
                                    revealedRecordingID: $viewModel.revealedRecordingID,
                                    onRename: { viewModel.piecePendingRename = $0 },
                                    onAdd: { _ in viewModel.showAlbumsComingSoon() },
                                    onDelete: { viewModel.piecePendingDelete = $0 }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y
                } action: { _, offsetY in
                    // Ignore top rubber-band; some builds report small negative values at rest.
                    let y = max(0, offsetY)
                    let collapsed: Bool
                    if y > headerCollapseScrollThreshold {
                        collapsed = true
                    } else if y < headerExpandScrollThreshold {
                        collapsed = false
                    } else {
                        collapsed = isHeaderCollapsed
                    }
                    if collapsed != isHeaderCollapsed {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isHeaderCollapsed = collapsed
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                RecordingsSearchBar(text: $viewModel.searchText)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .background(Color.clear)
            }

            if let message = viewModel.toastMessage {
                RecordingsToastView(message: message)
                    .padding(.top, 72)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation {
                                viewModel.clearToast()
                            }
                        }
                    }
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load()
        }
        .sheet(item: $viewModel.piecePendingRename) { piece in
            RenameRecordingSheet(piece: piece, viewModel: viewModel)
        }
        .alert(
            "Delete recording?",
            isPresented: Binding(
                get: { viewModel.piecePendingDelete != nil },
                set: { if !$0 { viewModel.piecePendingDelete = nil } }
            ),
            presenting: viewModel.piecePendingDelete
        ) { piece in
            Button("Delete", role: .destructive) {
                viewModel.deletePiece(id: piece.id)
                viewModel.piecePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                viewModel.piecePendingDelete = nil
            }
        } message: { piece in
            Text("“\(piece.title)” will be removed from your library.")
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.toastMessage)
    }
}

#Preview {
    let store = RecordingsStore.previewInstance()
    return NavigationStack {
        RecordingsView(store: store, viewModel: RecordingsViewModel(store: store))
    }
}
