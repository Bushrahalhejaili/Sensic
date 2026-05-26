//
//  PianoRollView.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 26/05/2026.
//


//
//  PianoRollView.swift
//  Sensic
//
//  Workspace › Creation › Edit Sheet
//  Vertically-scrolling piano roll that lives inside
//  EditSheetView.  Shows all 88 keys (A0 → C8) stacked top-to-
//  bottom from highest pitch to lowest, with the lanes (Navy
//  behind whites, IndigoBlue behind blacks) forming a backdrop
//  the note rectangles will eventually live in.
//
//  This file is JUST the piano + lane backdrop for now — the
//  time ruler / note rectangles will arrive in a follow-up
//  pass.
//
//  Drop this in: Views/Creation/
//

import SwiftUI

// MARK: - PianoRollView

/// 88-key vertical piano roll.
///
/// The geometry models a real piano: white keys form the spine
/// (each 24h, with a 2pt gap between every adjacent pair), and
/// black keys sit *on top* of the whites at the boundary
/// between specific pairs, centred on the 2pt spacing so they
/// overlap 5pt into the white above and 5pt into the white
/// below — the same way an actual piano keyboard reads when
/// you rotate it ninety degrees.
///
/// Drawing order, back-to-front:
///   1. Navy lanes (14h × 402w, centred behind each white key)
///   2. IndigoBlue lanes (12h × 402w, centred behind each
///      black key — fills the gap between the Navy lanes that
///      bracket the black-key position)
///   3. White keys (52 of them, flat left edge, rounded right
///      corners)
///   4. Black keys (36 of them, same shape, smaller — drawn
///      last so they sit on top of the whites they straddle)
struct PianoRollView: View {

    // MARK: Layout constants

    private let whiteKeyW:    CGFloat = 56
    private let whiteKeyH:    CGFloat = 24
    private let blackKeyW:    CGFloat = 36
    private let blackKeyH:    CGFloat = 12
    private let whiteLaneH:   CGFloat = 14
    private let blackLaneH:   CGFloat = 12
    private let laneW:        CGFloat = 402
    private let keyCornerR:   CGFloat = 10
    private let whiteSpacing: CGFloat = 2

    // MARK: Derived metrics

    /// Vertical pitch from one white key's top to the next: key
    /// height + gap = 26pt.
    private var whiteSlotH: CGFloat { whiteKeyH + whiteSpacing }

    /// Total scroll-content height = 52 white keys × 24h + 51
    /// gaps × 2pt = 1350pt.
    private var totalH: CGFloat {
        CGFloat(52) * whiteKeyH + CGFloat(51) * whiteSpacing
    }

    // MARK: Black-key pattern

    /// `true` if a black key lives between the white at `i` and
    /// the next white below (i+1).  Descending from C, the
    /// 7-white cycle is C–B–A–G–F–E–D; the only two transitions
    /// with no black between them are C→B (cycle index 0) and
    /// F→E (cycle index 4), so we exclude those.
    private func hasBlackAfter(_ i: Int) -> Bool {
        let c = i % 7
        return c != 0 && c != 4
    }

    // MARK: Y positions

    /// Top edge of the white key at index `i`.
    private func whiteKeyY(_ i: Int) -> CGFloat {
        CGFloat(i) * whiteSlotH
    }

    /// Top edge of the Navy lane behind white key `i` — centred
    /// vertically inside the 24h key, so 5pt below the key top.
    private func whiteLaneY(_ i: Int) -> CGFloat {
        whiteKeyY(i) + (whiteKeyH - whiteLaneH) / 2
    }

    /// Top edge of the black key sitting between whites `i` and
    /// `i+1`.  The black key's vertical centre lands in the
    /// middle of the 2pt gap, so its top is 5pt above the gap
    /// (= 19pt below the upper white's top).
    private func blackKeyY(after i: Int) -> CGFloat {
        whiteKeyY(i) + whiteKeyH + whiteSpacing / 2 - blackKeyH / 2
    }

    /// IndigoBlue lane top.  Lane and key share the same 12h, so
    /// the lane sits at the same Y as the key.
    private func blackLaneY(after i: Int) -> CGFloat {
        whiteKeyY(i) + whiteKeyH + whiteSpacing / 2 - blackLaneH / 2
    }

    // MARK: Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {

                // Layer 1 — Navy lanes (one per white key).
                ForEach(0..<52, id: \.self) { i in
                    navyLane.offset(y: whiteLaneY(i))
                }

                // Layer 2 — IndigoBlue lanes (one per black key,
                // filling the 12pt gap between the two Navy
                // lanes that bracket the black-key position).
                ForEach(0..<51, id: \.self) { i in
                    if hasBlackAfter(i) {
                        indigoLane.offset(y: blackLaneY(after: i))
                    }
                }

                // Layer 3 — White keys.
                ForEach(0..<52, id: \.self) { i in
                    whiteKey.offset(y: whiteKeyY(i))
                }

                // Layer 4 — Black keys, drawn last so they sit
                // on top of the two whites they overlap.
                ForEach(0..<51, id: \.self) { i in
                    if hasBlackAfter(i) {
                        blackKey.offset(y: blackKeyY(after: i))
                    }
                }
            }
            // Force the ZStack to its full 402×1350 footprint —
            // .offset doesn't grow the parent on its own, so
            // without this the ScrollView wouldn't know how tall
            // the content actually is.
            .frame(width: laneW, height: totalH, alignment: .topLeading)
        }
    }

    // MARK: - Components

    private var navyLane: some View {
        Rectangle()
            .fill(Color("Navy"))
            .frame(width: laneW, height: whiteLaneH)
    }

    private var indigoLane: some View {
        Rectangle()
            .fill(Color("IndigoBlue"))
            .frame(width: laneW, height: blackLaneH)
    }

    private var whiteKey: some View {
        UnevenRoundedRectangle(
            topLeadingRadius:     0,
            bottomLeadingRadius:  0,
            bottomTrailingRadius: keyCornerR,
            topTrailingRadius:    keyCornerR
        )
        .fill(Color.white)
        .frame(width: whiteKeyW, height: whiteKeyH)
    }

    private var blackKey: some View {
        UnevenRoundedRectangle(
            topLeadingRadius:     0,
            bottomLeadingRadius:  0,
            bottomTrailingRadius: keyCornerR,
            topTrailingRadius:    keyCornerR
        )
        .fill(Color.black)
        .frame(width: blackKeyW, height: blackKeyH)
    }
}

#Preview {
    Color.black
        .ignoresSafeArea()
        .overlay {
            PianoRollView()
        }
}
