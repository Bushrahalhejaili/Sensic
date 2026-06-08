//
//  CreationView.swift
//  Sensic
//  Created by Bushra Hatim Alhejaili on 19/05/2026.
//

//
//  CreationView.swift
//  Sensic
//  Created by Bushra Hatim Alhejaili on 19/05/2026.
//

import SwiftUI
import UIKit


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

    /// Vertical size class — `.compact` on iPhone in landscape,
    /// `.regular` on iPhone in portrait and on iPad in any
    /// orientation.  Gates the landscape-only Record-mode layout.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// True only when the timeline area in landscape Record mode
    /// has been tapped to expand to 293pt.  In that state the
    /// timeline fills its expanded height, the piano keys are
    /// hidden, and only the piano scroller stays visible at the
    /// bottom — tapping the scroller returns the layout to its
    /// compact 39pt timeline + piano arrangement.
    @State private var timelineExpanded: Bool = false

    /// iPhone landscape gate.  iPad's size classes are
    /// `.regular`/`.regular` in landscape so it stays on the
    /// portrait layout — the design is iPhone-only.  Also gated
    /// on `activeTab == .record` at every call site since
    /// landscape is permitted only inside Record mode.
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    enum Tab: Hashable { case record, practice }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Landscape Record mode uses a combined single-row
                // header that folds every toolbar control (undo,
                // redo, haptic toggle, transport) into the header
                // strip so the workspace below has the full
                // remaining height for the timeline + piano.
                // Every other configuration (portrait Record,
                // Practice) uses the regular two-row layout where
                // the toolbar lives inside `recordWorkspace`.
                Group {
                    if activeTab == .record && isLandscape {
                        landscapeRecordHeaderBar
                    } else {
                        headerBar
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)

                if activeTab == .record {
                    if isLandscape {
                        recordWorkspaceLandscape
                    } else {
                        recordWorkspace
                    }
                } else {
                    PracticeView(vm: practiceVM,
                                 scrollState: scrollState)
                }
            }
            // Pinning the VStack to the screen's full bounds with
            // top alignment is what keeps the header rock-stable
            // when the landscape timeline animates 39pt → 293pt.
            // Without this, the VStack sizes to its content and
            // gets centred inside the ZStack — and as the
            // workspace's content height changes during the
            // expand animation, the centring point shifts, which
            // pulls the whole VStack (header included) up and
            // down by a few pixels.  Filling maxHeight + .top
            // alignment fixes the header's y-origin at 0 and
            // makes the workspace absorb every height change
            // internally via its own Spacer.
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .top)
            // Horizontal safe-area opt-out keeps the header's
            // BUTTON POSITIONS rock-stable when the landscape edit
            // sheet appears or disappears.  Without this, adding
            // the edit-sheet view (which itself uses
            // `.ignoresSafeArea` to extend edge-to-edge) to the
            // ZStack alters the safe-area context that this
            // VStack inherits, and the VStack's resolved width
            // changes — which then redistributes the Spacers in
            // the header's HStack and shifts the back / save
            // buttons inward.  Pinning the VStack to the screen's
            // physical width here makes its width unconditional,
            // so the buttons' x-positions are determined purely
            // by the VStack's own `.padding(.horizontal, 16)`
            // and the landscape header's internal 20pt padding.
            //
            // In portrait this is a no-op (horizontal safe-area
            // insets are 0 on iPhones in portrait orientation).
            .ignoresSafeArea(.container, edges: .horizontal)
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

            // Landscape edit-sheet presentation — drawn as a
            // direct sibling of the header+workspace VStack
            // inside the body's ZStack rather than as an overlay
            // on the workspace.  Two reasons:
            //
            //   1. Edge-to-edge: anchoring to the workspace
            //      didn't work because SwiftUI's `.overlay` is
            //      laid out within the workspace's *layout*
            //      bounds even when the workspace draws past
            //      safe area via `.ignoresSafeArea`.  Attached
            //      to the ZStack instead, the sheet owns its own
            //      safe-area context and the `.ignoresSafeArea`
            //      below it makes it span the full device width
            //      and extend to the screen bottom.
            //
            //   2. Header stability: when the sheet was an
            //      overlay on the workspace, any layout
            //      reflow the workspace went through on sheet
            //      show/hide (timeline 41→90, Spacers and piano
            //      appearing or disappearing) was animated by
            //      the `.animation(value: showEditSheet)` on
            //      the workspace — and that reflow was bleeding
            //      out to the sibling header, shifting its
            //      buttons inward by a few pixels.  As a sibling
            //      of the VStack with its own scoped animation,
            //      the sheet's appearance can't affect the
            //      header at all.
            //
            // The `if let target = editingRecorder` mirrors the
            // same hydration pattern the old `.sheet` content
            // closure used.  The `.transition` slides the panel
            // up from below; the inline `.animation(...)` on the
            // transition is what fires the slide animation since
            // `showEditSheet` is flipped from `MainTimelineView`
            // (outside this view's `withAnimation` scope).
            if isLandscape && activeTab == .record
                && showEditSheet, let target = editingRecorder {
                VStack(spacing: 0) {
                    Spacer()
                    landscapeEditSheet(target: target)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container,
                                 edges: [.horizontal, .bottom])
                .transition(
                    .move(edge: .bottom)
                    .animation(.easeInOut(duration: 0.3))
                )
            }
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

            // Open up landscape only when entering Record mode.
            // Practice mode and every other screen in the app
            // remain portrait-only (see `AppDelegate`).
            AppOrientation.lock(
                to: activeTab == .record ? .allButUpsideDown : .portrait)
        }
        .onDisappear {
            // Leaving CreationView (back button, system pop, etc.)
            // returns the app to the global default of portrait.
            // If the device happens to be in landscape at the
            // moment of dismissal, `requestGeometryUpdate` will
            // rotate it back as the previous screen takes over.
            AppOrientation.lock(to: .portrait)
        }
        .onChange(of: activeTab) { _, newTab in
            // Switching to Practice mid-session must drop the
            // landscape allowance immediately and rotate back to
            // portrait if needed; switching back to Record
            // re-opens landscape.
            AppOrientation.lock(
                to: newTab == .record ? .allButUpsideDown : .portrait)
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

    /// Landscape variant of the header bar.  Per the Record-mode
    /// landscape design (Image 3 of the brief), the layout is:
    ///
    ///   back  | ←Spacer→ | undo • redo • haptic • segment • transport | ←Spacer→ | save
    ///
    /// Back and save anchor the two edges with their own 20pt
    /// horizontal inset (on top of the body's 16pt) so they sit
    /// well clear of the screen corners.  The middle group is a
    /// nested `HStack(spacing: 10)` so every control inside it
    /// (the three round buttons, the segment picker, the
    /// transport bar) shares the same 10pt rhythm and stays
    /// visually tied to the segment picker rather than drifting
    /// left.  The two `Spacer(minLength: 0)`s distribute the
    /// remaining horizontal space equally, centring the middle
    /// group between back and save.
    ///
    /// Only ever used when `activeTab == .record && isLandscape`.
    /// In every other configuration the regular `headerBar` and
    /// the in-workspace `toolBar` are used instead.
    private var landscapeRecordHeaderBar: some View {
        HStack(spacing: 0) {
            SensicGlassCircleButton(
                systemName: "chevron.left",
                iconSize: 20,
                iconColor: .white,
                action: { dismiss() }
            )

            Spacer(minLength: 0)

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

                segmentPicker

                transportBar
            }

            Spacer(minLength: 0)

            SensicGlassCircleButton(
                systemName: "checkmark",
                iconSize: 20,
                iconColor: .white,
                isActive: saveButtonIsActive,
                action: handleSaveTap
            )
        }
        // Extra horizontal padding on top of the body's 16pt.
        // 16 + 20 = 36pt from the screen edge to the back and
        // save buttons, which keeps them clear of the device's
        // rounded corners (and the dynamic island when the
        // window scene's safe-area insets are smaller than
        // expected).
        .padding(.horizontal, 20)
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

    // MARK: - Workspace (landscape)

    /// Record-mode workspace for iPhone landscape (Image 1–3).
    /// Three visual states:
    ///
    ///   A — default (compact timeline, piano showing):
    ///       Spacer | timeline | Spacer | scroller 25pt | 5pt | piano 220pt | 5pt
    ///       (the two Spacers are equal, vertically centring the
    ///       timeline in the empty area between the header and
    ///       the scroller.)
    ///   B — timeline expanded (tap timeline):
    ///       Spacer | timeline 293pt | Spacer | scroller 25pt | 5pt
    ///       (Spacers still equal — each ~5pt — so the timeline
    ///       remains centred even when it nearly fills the
    ///       workspace.)
    ///   C — edit sheet open:
    ///       timeline 87pt | (sheet covers below)
    ///       (no Spacers — gated on `!showEditSheet` so the
    ///       timeline anchors at the workspace top and isn't
    ///       hidden under the 230pt sheet.)
    ///
    /// The two `Spacer(minLength: 0)`s do the centring work.
    /// SwiftUI distributes the workspace's leftover height
    /// equally between them, so whatever the timeline's
    /// current height is (41, 87, 293, anything else the
    /// designer picks later), the gap above it always equals
    /// the gap below it.  Pinning the workspace to
    /// `maxHeight: .infinity, alignment: .top` keeps its outer
    /// height constant across state changes, which is how the
    /// header above stays put when the user expands the timeline.
    ///
    /// The portrait `recordWorkspace` is untouched — landscape
    /// runs entirely through this branch.
    private var recordWorkspaceLandscape: some View {
        VStack(spacing: 0) {

            // State A & B: top half of the centring pair.
            // Together with the matching Spacer below the
            // timeline, this splits the workspace's leftover
            // vertical space evenly, leaving the timeline
            // visually centred between the header and the
            // scroller.  Gated on `!showEditSheet` so state C
            // anchors the timeline at the workspace top instead
            // of pushing it into the sheet's coverage area.
            if !showEditSheet {
                Spacer(minLength: 0)
            }

            landscapeTimeline

            if !showEditSheet {

                // Bottom half of the centring pair — equal to
                // the Spacer above the timeline because SwiftUI
                // splits leftover space evenly between sibling
                // Spacers.  Replaces the previous fixed 10pt
                // padding so the gap above and below the
                // timeline always match.
                Spacer(minLength: 0)

                // Piano scroller — always visible when the edit
                // sheet is closed.  In state B it doubles as the
                // tap target that returns to state A.  Sized to
                // the landscape dimensions specified in the
                // design (864 × 25).  The 5pt bottom padding
                // becomes "gap to piano" in state A and "gap to
                // screen bottom" in state B, where the scroller
                // ends up at the workspace's bottom edge.
                //
                // `.padding(.bottom, 5)` is applied AFTER the
                // tap modifiers so the tap region stays bound
                // to the scroller's own 864×25 rectangle and
                // doesn't include the gap below it.
                PianoScroller(scrollState: scrollState, landscape: true)
                    .frame(width: PianoScroller.landscapeWidth,
                           height: PianoScroller.landscapeHeight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if timelineExpanded {
                            withAnimation(.spring(response: 0.4,
                                                  dampingFraction: 0.86)) {
                                timelineExpanded = false
                            }
                        }
                    }
                    .padding(.bottom, 5)

                // Piano keys — only in state A.  Same dimensions
                // as portrait (white-key height = 220pt) so the
                // keys themselves are identical; the keyboard is
                // wider here because the parent container extends
                // edge-to-edge, which is what makes more keys
                // visible at any one time.
                if !timelineExpanded {
                    PianoSection(vm: recordVM, scrollState: scrollState)
                        .frame(height: wKH)
                        .padding(.bottom, 5)
                }
            }
        }
        // Workspace fills every pixel the parent VStack gives it
        // (which is "screen height minus header"), top-aligned so
        // the haptic card (when shown) anchors at the top while
        // the Spacer pair below it splits the rest.  Keeping the
        // workspace's outer height CONSTANT across state changes
        // is what guarantees the header above never shifts when
        // the timeline expands.
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: .top)
        // Haptic settings card in landscape — floats over the
        // workspace (above the timeline / scroller / piano)
        // instead of pushing the layout down.  Anchored to the
        // workspace's top-leading corner because the workspace
        // already ignores horizontal safe area, so the leading
        // padding is measured from the screen's leading edge
        // regardless of any notch / dynamic-island inset.  The
        // 240pt leading offset roughly lines the card up with
        // the slider-icon button in the header that triggered
        // it; the 5pt top offset puts it just below the header
        // line.  Transition matches the portrait card so the
        // animation feels consistent between orientations.
        .overlay(alignment: .topLeading) {
            if showHapticCard {
                HapticSettingsCard(settings: hapticSettings)
                    .padding(.leading, 240)
                    .padding(.top, 5)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Edge-to-edge horizontally so the timeline and piano
        // span both sides of the screen (per spec), and bottom-
        // anchored so the piano sits flush with the bottom of
        // the device.  Keyboard region is opted out for the same
        // reason as the portrait workspace: keep the layout from
        // shifting under the save alert's keyboard.
        .ignoresSafeArea([.container, .keyboard],
                         edges: [.horizontal, .bottom])
    }

    /// Custom edit-sheet presentation for landscape Record mode.
    /// Renders as a `.bottom`-anchored overlay on the workspace
    /// instead of using SwiftUI's `.sheet`, because `.sheet` in
    /// landscape on iPhone (regular width × compact height) is
    /// presented as a centred form-sheet with hard-coded
    /// horizontal margins, regardless of `.presentationDetents`
    /// or `.presentationCompactAdaptation(.sheet)`.  By drawing
    /// our own panel we get edge-to-edge presentation and avoid
    /// the safe-area inset changes that the form-sheet machinery
    /// imposes on the underlying view (which were shifting the
    /// header buttons inward whenever the sheet was shown).
    ///
    /// A 20pt drag-handle strip at the top hosts a 36×5 capsule
    /// indicator and the dismiss `DragGesture`.  Limiting the
    /// gesture to that strip (via `.contentShape(Rectangle())`
    /// inside the strip's own bounds) means swiping anywhere on
    /// the piano roll below doesn't dismiss the sheet — the roll's
    /// own touch handling stays intact.
    @ViewBuilder
    private func landscapeEditSheet(target: TrackRecorder) -> some View {
        VStack(spacing: 0) {

            // Drag-to-dismiss strip — gesture is scoped to this
            // 19pt region only, so the piano roll keeps its own
            // pan / touch gestures uncontested.
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // Match the standard sheet's dismiss
                        // threshold: a downward drag of more
                        // than ~50pt triggers dismiss.  The
                        // `.animation` modifier on the workspace
                        // animates the `.move(edge: .bottom)`
                        // transition as the flag flips.
                        if value.translation.height > 50 {
                            showEditSheet = false
                        }
                    }
            )

            // Piano roll content.  EditSheetView's wrapper view
            // adds a NavigationStack chrome and a 24pt top
            // padding that were only there to leave room for the
            // sheet's navigation bar — since we're not in a
            // presented sheet, neither is needed here, so
            // PianoRollView is rendered directly.
            PianoRollView(recorder: target)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 230)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 16
            )
            .fill(Color("TransparentSpaceBlue"))
        )
    }

    /// Timeline section for landscape mode.  Three heights map
    /// to the three states on `recordWorkspaceLandscape`:
    ///
    ///   • edit sheet open  →  87pt — track-band height that
    ///     leaves room for the 230pt edit sheet below.
    ///   • expanded         →  293pt — full track with note bars
    ///     visible.
    ///   • default          →  39pt — ruler + track header band
    ///     only.
    ///
    /// The `GeometryReader` is what gives the inner
    /// `MainTimelineView` its width: SwiftUI proposes the
    /// workspace's full edge-to-edge width to the reader, which
    /// passes it down as `containerWidth`.  That parameter
    /// replaces the timeline's hard-coded 402pt portrait width
    /// so the same view renders edge-to-edge in landscape
    /// without breaking portrait at the call sites that don't
    /// pass it.
    ///
    /// The whole region is tappable.  A tap on the compact
    /// timeline triggers the expand transition; the return path
    /// is via the piano scroller below (so the scroller stays
    /// reachable in the expanded state).
    @ViewBuilder
    private var landscapeTimeline: some View {
        let height: CGFloat = {
            if showEditSheet { return 90 }
            return timelineExpanded ? 293 : 41
        }()

        GeometryReader { proxy in
            MainTimelineView(
                recorder: recorder,
                pastedTracks: $pastedTracks,
                showEditSheet: $showEditSheet,
                editingRecorder: $editingRecorder,
                containerWidth: proxy.size.width
            )
            .frame(width: proxy.size.width,
                   height: proxy.size.height,
                   alignment: .top)
            .clipped()
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !showEditSheet, !timelineExpanded else { return }
            withAnimation(.spring(response: 0.4,
                                  dampingFraction: 0.86)) {
                timelineExpanded = true
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
