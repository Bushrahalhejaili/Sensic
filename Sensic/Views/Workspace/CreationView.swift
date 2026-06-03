//
//  CreationView.swift
//  Sensic
//


import SwiftUI


// MARK: - CreationView

struct CreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: RecordingsStore
    var onSavedToRecordings: (() -> Void)?

    // recordVM is still here because PianoWithScroller takes it and
    // the piano keys need a model for live audio + visual feedback.
    // None of its recording APIs are called from this view anymore.
    @ObservedObject private var recordVM = AudioEngine.shared
    @ObservedObject private var hapticSettings = HapticSettings.shared
    @StateObject private var practiceVM = PracticeViewModel()
    @StateObject private var scrollState = PianoScrollState()
    @StateObject private var recorder = TrackRecorder()

    @State private var activeTab: Tab = .record

    /// Whether the haptic settings card is presented above the
    /// timeline.  Toggled by the slider-icon button in the toolbar.
    /// When true, the card slides in and the timeline shrinks from
    /// 349pt to 169pt to make room.
    @State private var showHapticCard = false

    /// Whether the bottom Edit sheet is presented.  Flipped to
    /// `true` from `MainTimelineView` when the user picks "Edit"
    /// on a track's edit menu, and back to `false` when the sheet
    /// is dismissed (drag-down or Done button).  The same flag
    /// drives the conditional workspace layout: piano below the
    /// timeline when false, a 10pt gap + 322pt placeholder when
    /// true so the sheet has room to slide in.
    @State private var showEditSheet: Bool = false

    /// The track currently being edited by the sheet — set by
    /// `MainTimelineView` at the same instant it flips
    /// `showEditSheet` to true.  Held here (rather than inside
    /// the timeline) so the `.sheet` modifier on the workspace
    /// can read it when constructing `EditSheetView`.  Cleared
    /// on dismiss so a stale reference can't leak into the next
    /// presentation.
    @State private var editingRecorder: TrackRecorder? = nil

    enum Tab: Hashable { case record, practice }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                if activeTab == .record {
                    recordWorkspace
                } else {
                    PracticeView(vm: practiceVM)
                }
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Subscribe the recorder to live key presses on the
            // Record-tab piano.  Notes are only captured while the
            // recorder's `isRecording` flag is true.
            recorder.bind(to: recordVM)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            SensicGlassCircleButton(
                systemName: "chevron.left",
                iconSize: 20,
                iconColor: .white,
                action: { dismiss() }
            )

            Spacer(minLength: 0)

            segmentPicker

            Spacer(minLength: 0)

            if activeTab == .record {
                SensicGlassCircleButton(
                    systemName: "checkmark",
                    iconSize: 20,
                    iconColor: .white,
                    action: {} // no-op
                )
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
        }
    }

    @Namespace private var segNamespace

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            segmentLabel("Record",   tab: .record)
            segmentLabel("Practice", tab: .practice)
        }
        .padding(3)
        .background(Color("Navy"))
        .clipShape(Capsule())
        .frame(width: 214, height: 44)
    }

    private func segmentLabel(_ title: String, tab: Tab) -> some View {
        let selected = activeTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                activeTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color("MainPurple"))
                            .matchedGeometryEffect(
                                id: "segThumb", in: segNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Workspace

    private var recordWorkspace: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            toolBar
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 10)

            // Haptic settings card — slides in between the toolbar
            // and the timeline when the slider-icon button is tapped.
            // Practice mode shows the same card always-visible; here
            // it's behind a trigger so the timeline keeps the full
            // workspace by default.
            if showHapticCard {
                HapticSettingsCard(settings: hapticSettings)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Timeline shrinks from 349 → 169 when the card is up.
            // The internal layout still renders at 349pt; `.clipped()`
            // hides the bottom portion so the ruler at the top stays
            // visible and any tracks remain in place when the card
            // closes again.
            MainTimelineView(recorder: recorder,
                             showEditSheet: $showEditSheet,
                             editingRecorder: $editingRecorder)
                .frame(maxWidth: .infinity)
                .frame(height: showHapticCard ? 169 : 349,
                       alignment: .top)
                .clipped()

            // Piano stays mounted (preserves audio + scroll state)
            // but is hidden while the edit sheet is up.  Using
            // `.opacity(0)` keeps the section's layout footprint
            // intact so the rest of the page can't shift; toggling
            // hit-testing off prevents stray taps from leaking
            // through the invisible keys.
            PianoWithScroller(
                vm: recordVM,
                scrollState: scrollState
            )
            .frame(height: CreationLayout.pianoBlockHeight)
            .padding(.top, 30)
            .padding(.bottom, 9)
            .opacity(showEditSheet ? 0 : 1)
            .allowsHitTesting(!showEditSheet)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(isPresented: $showEditSheet,
               onDismiss: { editingRecorder = nil }) {
            // `editingRecorder` is set by MainTimelineView *before*
            // it flips `showEditSheet` to true, so it's already
            // populated by the time SwiftUI builds this content.
            // Guarded just in case the order ever inverts.
            if let target = editingRecorder {
                EditSheetView(recorder: target)
                    .presentationDetents([.height(322)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Toolbar

    private var toolBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                SensicGlassCircleButton(
                    systemName: "arrow.uturn.backward",
                    iconSize: 20,
                    iconColor: recorder.canUndo
                        ? Color("MainPurple")
                        : Color("MainPurple").opacity(0.35),
                    action: { recorder.undoTapped() }
                )

                SensicGlassCircleButton(
                    systemName: "arrow.uturn.forward",
                    iconSize: 20,
                    iconColor: recorder.canRedo
                        ? Color("MainPurple")
                        : Color("MainPurple").opacity(0.35),
                    action: { recorder.redoTapped() }
                )

                SensicGlassCircleButton(
                    systemName: "slider.horizontal.3",
                    iconSize: 20,
                    iconColor: showHapticCard ? .white : Color("MainPurple"),
                    isActive: showHapticCard,
                    action: {
                        withAnimation(.spring(response: 0.38,
                                              dampingFraction: 0.86)) {
                            showHapticCard.toggle()
                        }
                    }
                )
            }

            Spacer(minLength: 47)

            transportBar
        }
    }

    // MARK: - Transport bar

    /// Green tint for the play button while the playhead is
    /// advancing (whether the user is in a recording or playback
    /// session).
    private var activeGreen: Color {
        Color(red: 0.30, green: 0.85, blue: 0.40)
    }

    /// Light grey tint for the stop button while the playhead is
    /// advancing — visually softens it without making it look
    /// disabled.
    private var activeGrey: Color {
        Color(white: 0.65)
    }

    private var transportBar: some View {
        // Read the two state flags up front so the closures don't
        // capture the recorder reference more than necessary.
        let isAdvancing = recorder.isAdvancing
        let isRecording = recorder.isRecording

        return HStack(spacing: 4) {
            transportIcon("backward.fill") { recorder.skipBackwardTapped() }
            transportIcon("forward.fill")  { recorder.skipForwardTapped() }
            transportIcon(
                "stop.fill",
                color: isAdvancing ? activeGrey : .white,
                action: { recorder.stopTapped() }
            )
            transportIcon(
                "play.fill",
                color: isAdvancing ? activeGreen : .white,
                action: { recorder.playTapped() }
            )
            transportIcon(
                "circle.fill",
                size: 17,
                weight: .bold,
                color: isRecording ? Color("RecordingRed") : .white,
                action: { recorder.recordTapped() }
            )
        }
        .frame(width: 171, height: 44)
        .background(
            Capsule()
                .fill(Color("Navy").opacity(0.95))
                .overlay(
                    Capsule().strokeBorder(
                        SensicGlassChrome.glassShineGradient,
                        lineWidth: 0.4
                    )
                )
                .glassEffect(.clear.interactive())
        )
    }

    private func transportIcon(
        _ name: String,
        size: CGFloat = 20,
        weight: Font.Weight = .semibold,
        color: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreationView(store: .previewInstance())
}
