//
//  CreationRecordView.swift
//  Sensic
//
//  Created by شهد عبدالله القحطاني on 01/12/1447 AH.
//

import SwiftUI

struct CreationRecordView: View {
    @ObservedObject var recordVM: RecordViewModel
    @ObservedObject var practiceVM: PracticeViewModel

    @StateObject private var scrollState = PianoScrollState()

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            PianoWithScroller(
                vm: recordVM,
                scrollState: scrollState
            )
        }
        .padding(.top, 8)
    }
}


