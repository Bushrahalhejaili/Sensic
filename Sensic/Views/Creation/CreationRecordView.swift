//
//  CreationRecordView.swift
//  Sensic
//
//  Created by شهد عبدالله القحطاني on 01/12/1447 AH.
//

import Foundation
import SwiftUI
import AVFoundation


struct CreationRecordView: View {
    @ObservedObject var recordVM: RecordViewModel
    @ObservedObject var practiceVM: PracticeViewModel
 
    @State private var showNewSession  = false
    @State private var newTitle        = ""
    @State private var hapticIntensity: Float = 0.7
    @State private var hapticSharpness: Float = 0.5
    @State private var hapticStyle: HapticStyle = .smooth
    @StateObject private var scrollState = PianoScrollState()
 
    var body: some View {
        VStack(spacing: 12) {
            // Timeline
            TimelineView(
                isRecording: recordVM.isRecording,
                noteHistory: recordVM.noteHistory,
                elapsed: recordVM.elapsedSeconds
            )
            .frame(height: 90)
            .padding(.horizontal, 16)
 
            // Haptic controls
            HapticControlsView(
                intensity: $hapticIntensity,
                sharpness: $hapticSharpness,
                style: $hapticStyle
            )
            .padding(.horizontal, 16)
 
            // Timer / controls
            HStack {
                if recordVM.isRecording {
                    Text(recordVM.formattedTime)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Discard") { recordVM.discardRecording() }
                        .font(.subheadline).foregroundStyle(SensicColors.secondaryText)
                } else {
                    Spacer()
                    Button {
                        showNewSession = true
                    } label: {
                        Label("Start recording", systemImage: "record.circle")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(SensicColors.accentPurple)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
 
            Spacer(minLength: 0)
 
            // Piano
            PianoWithMinimap(
                vm: recordVM,
                scrollState: scrollState,
                hapticIntensity: hapticIntensity,
                hapticSharpness: hapticSharpness,
                hapticStyle: hapticStyle
            )
        }
        .padding(.top, 8)
        .sheet(isPresented: $showNewSession) {
            NewSessionSheet(title: $newTitle) {
                recordVM.startRecording(title: newTitle)
                newTitle = ""
                showNewSession = false
            } onCancel: { showNewSession = false }
        }
    }
}
 
