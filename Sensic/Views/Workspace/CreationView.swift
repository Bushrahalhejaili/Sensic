//
//  CreationView.swift
//  Sensic
//  Created by Bushra Hatim Alhejaili on 19/05/2026.
//

import SwiftUI


// MARK: - CreationView

struct CreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: RecordingsStore

    /// When non-nil, the view hydrates its recorder + pastedTracks
    /// from this piece on first appearance.  Treated as the
    /// "currently saved" state, so the checkmark button starts in
    /// its active (MainPurple) form and any subsequent edit makes
    /// it inactive (Navy) until the user re-saves.
    var loadingPiece: Piece? = nil

    /// Optional callback kept for compatibility with the existing
    /// "open Recordings after first save" flow.  No longer fired
    /// by the save action itself — saves stay on this page now.
    var onSavedToRecordings: (() -> Void)? = nil

    // recordVM is still here because PianoWithScroller takes it and
    // the piano keys need a model for live audio + visual feedback.
    // None of its recording APIs are called from this view anymore.
    @ObservedObject private var recordVM = AudioEngine.shared
    @ObservedObject private var hapticSettings = HapticSettings.shared
    @StateObject private var practiceVM = PracticeViewModel()
    @StateObject private var scrollState = PianoScrollState()
    @StateObject private var recorder = TrackRecorder()

    /// All Paste-created tracks on the timeline.  Owned here (not
    /// inside `MainTimelineView`) so the save flow can read every
    /// track when building the saved `Piece`.  `MainTimelineView`
    /// receives it as a `@Binding` and continues to add/remove
    /// entries when the user pastes or undoes a paste.
    @State private var pastedTracks: [TrackRecorder] = []

    @State private var activeTab: Tab = .record

    /// Whether the haptic settings card is presented above the
    /// timeline.  Toggled by the slider-icon button in the toolbar.
    /// When true, the card slides in and the timeline shrinks from
    /// 349pt to 169pt to make room.
    @State private var showHapticCard = false

    /// Drives the "Enter New Name" alert that confirms the save.
    /// While true, the checkmark button in the header shows its
    /// active (MainPurple-filled) state — mirroring the haptic
    /// toggle's pattern — and the alert is visible above the
    /// workspace.  Reset to false on Save or Cancel.
    @State private var showSaveAlert = false

    /// Working buffer for the alert's text field.  Cleared each
    /// time the alert is opened so the user always starts from
    /// the placeholder rather than the previous attempt.
    @State private var saveTitle = ""

    /// ID of the saved `Piece` this session corresponds to — nil
    /// before the first save (a brand-new session) or after a
    /// fresh "New" load.  Once set, subsequent taps on the save
    /// button skip the rename alert and call `updatePiece` instead
    /// of `savePiece`, so the user updates in place rather than
    /// creating a new entry.
    @State private var savedPieceID: UUID? = nil

    /// Signature of the recorder + pastedTracks at the moment of
    /// the last save (or load).  Compared against `currentSignature`
    /// each render to decide whether the user has unsaved changes:
    /// if the signatures match, the save button is in its active
    /// (MainPurple) state; if they diverge, it's back to Navy.
    /// Nil means "never saved this session" — the button starts
    /// inactive in that case.
    @State private var savedSignature: String? = nil

    /// True only during the brief window of loading a piece from
    /// `onAppear`.  Prevents the view from observing its own
    /// load-side state mutations as user edits.
    @State private var isLoading = false

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
                    PracticeView(vm: practiceVM,
                                 scrollState: scrollState)
                }
            }
            // Per Apple's `View.ignoresSafeArea(_:edges:)`
            // documentation, a child view's `ignoresSafeArea`
            // modifier with explicit regions shadows the parent's
            // setting for the same edge.  The outer ZStack opts
            // out of `.keyboard` on the bottom edge, but the inner
            // VStack is a separate layout container that
            // arranges its children using its own safe-area
            // context.  Without this explicit opt-out on the
            // VStack, it would re-apply the keyboard inset when
            // distributing space to `headerBar` and
            // `recordWorkspace`, compressing the layout and
            // sliding the header up.
            //
            // Apple docs:
            // https://developer.apple.com/documentation/swiftui/view/ignoressafearea(_:edges:)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        // Root-level opt-out for the keyboard safe area, per
        // Apple's canonical pattern for views that should stay
        // anchored when the keyboard appears.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Save alert — uses the native iOS alert, which on iOS 26
        // already comes with Liquid Glass, a proper system
        // backdrop, automatic keyboard avoidance, and return-key
        // submit behavior.  An earlier version rebuilt all of
        // this as a custom view with manual `glassEffect` calls
        // and a hand-rolled dim layer; the native API does it
        // better and matches the design exactly.
        .alert("Name Recording", isPresented: $showSaveAlert) {
            TextField("Name", text: $saveTitle)

            Button("Cancel", role: .cancel) { }

            Button("Save") {
                performSave()
            }
            .disabled(
                saveTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        } message: {
            Text("Enter a name for this recording.")
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Subscribe the recorder to live key presses on the
            // Record-tab piano.  Notes are only captured while the
            // recorder's `isRecording` flag is true.
            recorder.bind(to: recordVM)

            // First-appearance load: if the user opened this view
            // by tapping an existing recording, hydrate the
            // recorder + pastedTracks from it and treat that
            // hydrated state as "saved" so the button starts in
            // its active form.  Gated on savedPieceID so a re-
            // appearance (e.g. coming back from the edit sheet)
            // doesn't wipe in-progress changes.
            if let piece = loadingPiece, savedPieceID == nil {
                loadPiece(piece)
            }
        }
    }

    // MARK: - Save

    /// Called when the user taps the checkmark.  Two paths:
    ///
    /// 1. First save in this session (no `savedPieceID` yet): open
    ///    the "Enter New Name" alert so the user can title their
    ///    project.  `performSave` runs on confirm.
    /// 2. Subsequent save (we already have a `savedPieceID`): skip
    ///    the alert and call `performSave` straight away — the
    ///    existing piece is updated in place and the typed title
    ///    is reused.
    private func handleSaveTap() {
        if savedPieceID == nil {
            saveTitle = ""
            showSaveAlert = true
        } else {
            performSave()
        }
    }

    /// Gather every track on the timeline — the primary recorder
    /// plus any pasted/archived tracks — and persist them as a
    /// single `Piece` in the store.
    ///
    /// On the first save we call `savePiece` (which creates a new
    /// entry, prepended in the library) and remember the id in
    /// `savedPieceID`.  On subsequent saves we call `updatePiece`
    /// so the same library entry is refreshed in place rather
    /// than duplicated.
    ///
    /// Each track's notes are offset by that track's
    /// `trackStartSec` in the flat `noteEvents` array so the
    /// waveform shape and any single-track playback path keeps
    /// using absolute project time.  The full multi-track
    /// structure is also captured (via `recorder.snapshot()` and
    /// `track.snapshot()`) into `trackSnapshots` so reopening the
    /// recording restores every track exactly where the user
    /// left it.  Track names ride along inside each snapshot;
    /// the project's `title` is independent of them.
    private func performSave() {
        // For a first save, the alert supplies the title.  For an
        // update save, we won't even read this string — the
        // existing piece keeps its title.
        let trimmed = saveTitle.trimmingCharacters(
            in: .whitespacesAndNewlines)

        // Flatten every track's notes into one event list in
        // absolute project time.
        var events = recorder.noteEvents(
            timeOffset: recorder.trackStartSec)
        for track in pastedTracks where !track.isDeleted {
            events.append(contentsOf: track.noteEvents(
                timeOffset: track.trackStartSec))
        }
        events.sort { $0.timestamp < $1.timestamp }

        // Per-track snapshots — for faithful restore later.
        var snapshots: [TrackSnapshot] = [recorder.snapshot()]
        for track in pastedTracks where !track.isDeleted {
            snapshots.append(track.snapshot())
        }

        // Project duration = the latest track-end across the board.
        let primaryEnd = recorder.trackStartSec
            + recorder.recordedDuration
        let pastedEnds = pastedTracks
            .filter { !$0.isDeleted }
            .map { $0.trackStartSec + $0.recordedDuration }
        let totalDuration = ([primaryEnd] + pastedEnds).max() ?? 0

        if let existingID = savedPieceID {
            // Update path — keeps the title, refreshes the rest.
            store.updatePiece(
                id:             existingID,
                duration:       totalDuration,
                noteEvents:     events,
                trackSnapshots: snapshots)
        } else {
            // First save — needs a title.  Bail if empty (defensive;
            // the alert's Save button is already disabled when the
            // text is empty).
            guard !trimmed.isEmpty else { return }
            let piece = store.savePiece(
                title:          trimmed,
                duration:       totalDuration,
                noteEvents:     events,
                trackSnapshots: snapshots)
            savedPieceID = piece.id
        }

        // Sync the saved-signature so the button immediately
        // settles into its active (MainPurple) state.  Any further
        // edit will diverge from this signature and flip the
        // button back to inactive.
        savedSignature = currentSignature

        showSaveAlert = false
        saveTitle     = ""
    }

    // MARK: - Load

    /// Hydrate the recorder + pastedTracks from a stored piece.
    /// Preference order: use `piece.trackSnapshots` if present
    /// (preserves the multi-track layout); fall back to the flat
    /// `piece.noteEvents` on a single primary track for any
    /// legacy entries saved before the snapshot field existed.
    ///
    /// Sets `savedPieceID` and `savedSignature` after hydration
    /// so the button starts in its "saved" (active) state.
    private func loadPiece(_ piece: Piece) {
        isLoading = true
        defer { isLoading = false }

        if let snapshots = piece.trackSnapshots, !snapshots.isEmpty {
            recorder.loadFully(snapshots[0])
            pastedTracks = snapshots.dropFirst().map { snap in
                let t = TrackRecorder()
                t.loadFully(snap)
                if let vm = recorder.audioOutput {
                    t.bind(to: vm)
                }
                return t
            }
        } else {
            // Legacy fallback — flat note list onto the primary.
            let restored = piece.noteEvents.map { event in
                RecordedNote(
                    midi:         event.midiNote,
                    startSeconds: event.timestamp,
                    endSeconds:   event.timestamp + event.duration,
                    velocity:     event.velocity)
            }
            recorder.loadFully(TrackSnapshot(
                notes:         restored,
                duration:      piece.duration,
                name:          "Piano",
                trackStartSec: 0,
                trackRow:      0))
            pastedTracks = []
        }

        savedPieceID   = piece.id
        savedSignature = currentSignature
    }

    // MARK: - Dirty tracking

    /// True when the user has at least one piece of unsaved
    /// content on the timeline that doesn't match the last
    /// persisted version.  Drives the save button's active state.
    private var hasUnsavedChanges: Bool {
        guard let saved = savedSignature else {
            // Never saved this session — anything except a
            // completely empty timeline counts as unsaved work.
            return !recorder.notes.isEmpty
                || !pastedTracks.allSatisfy { $0.notes.isEmpty }
        }
        return currentSignature != saved
    }

    /// Save button uses MainPurple-filled (active) when EITHER the
    /// save alert is open OR the user has a saved piece and
    /// hasn't touched it since.
    private var saveButtonIsActive: Bool {
        if showSaveAlert { return true }
        if savedPieceID != nil && !hasUnsavedChanges { return true }
        return false
    }

    /// Compact, stable string description of the current timeline
    /// state — duration, position, row, and the note list of every
    /// non-deleted track.  Compared against `savedSignature` to
    /// detect whether the user has made edits since the last save.
    /// Track name is included so per-track renames also count as
    /// edits that warrant a re-save.
    private var currentSignature: String {
        var parts: [String] = []
        func append(_ t: TrackRecorder) {
            parts.append("name:\(t.trackName)")
            parts.append("dur:\(t.recordedDuration)")
            parts.append("start:\(t.trackStartSec)")
            parts.append("row:\(t.trackRow)")
            parts.append("count:\(t.notes.count)")
            for n in t.notes {
                parts.append("\(n.midi),\(n.startSeconds),\(n.endSeconds ?? -1),\(n.velocity)")
            }
        }
        append(recorder)
        for track in pastedTracks where !track.isDeleted {
            append(track)
        }
        return parts.joined(separator: "|")
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
                    isActive: saveButtonIsActive,
                    action: handleSaveTap
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
                // Use a semantic text style (`.subheadline`)
                // rather than a fixed `.system(size: 15)` so the
                // label scales with the user's Dynamic Type
                // setting — both the normal range under Settings
                // → Display & Brightness → Text Size and the
                // larger range under Accessibility → Display &
                // Text Size → Larger Text.  `.subheadline` is
                // 15pt at the system default, so the visual size
                // at the default setting is unchanged.
                //
                // Apple HIG, "Typography":
                // https://developer.apple.com/design/human-interface-guidelines/typography
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                // The segment picker has a fixed 214pt width
                // (it has to sit between the chevron and the
                // checkmark in the header bar).  At the largest
                // accessibility sizes a scaled subheadline can
                // overflow that width — `.minimumScaleFactor(0.7)`
                // lets the label shrink to 70% of its scaled size
                // before truncating, and `.lineLimit(1)` keeps it
                // on a single line.  Apple HIG: "Verify that text
                // doesn't truncate or clip in your layout, even
                // at the largest text size."
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
                             pastedTracks: $pastedTracks,
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
        // Per Apple's `SafeAreaRegions` docs, this is an
        // OptionSet, and a child view's `.ignoresSafeArea(...)`
        // with explicit regions shadows the parent's setting for
        // the same edge.  This view needs to opt out of BOTH:
        //
        //   • `.container` — to extend the piano past the home
        //     indicator at the actual screen bottom (an existing
        //     requirement of the design).
        //   • `.keyboard` — to keep the layout from compressing
        //     upward when the save alert's keyboard appears, so
        //     the toolbar, timeline, and piano stay anchored
        //     where they were.
        //
        // Listing only `.container` here (as an earlier version
        // did) would shadow the outer `.ignoresSafeArea(.keyboard,
        // edges: .bottom)` and re-apply the keyboard inset on
        // this subtree's bottom edge.  Listing both keeps the
        // parent's keyboard opt-out alive for this child.
        //
        // Apple docs:
        // https://developer.apple.com/documentation/swiftui/safearearegions
        // https://developer.apple.com/documentation/swiftui/view/ignoressafearea(_:edges:)
        .ignoresSafeArea([.container, .keyboard], edges: .bottom)
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
