//
//  Onb3.swift
//  Sensic
//
//  Created by راما بدر بن جامع on 02/12/1447 AH.
//

import SwiftUI

struct Onb3: View {
    
    @State private var showHome = false

    var body: some View {
        
        if showHome {
            
            HomeView()
            
        } else {
            
            ZStack {
                
                // Background
                Image("Ong")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                VStack {
                    
                    Spacer()
                    
                    // Dots
                    HStack(spacing: 8) {
                        
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 10, height: 10)
                        
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 10, height: 10)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                    }
                    .padding(.bottom, 34)
                    
                    // Get Started Button
                    Button(action: {
                        showHome = true
                    }) {
                        Text("Get Started")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                Color(
                                    red: 139/255,
                                    green: 91/255,
                                    blue: 173/255
                                ) // #8B5BAD
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 33)
                                    .stroke(
                                        Color(
                                            red: 45/255,
                                            green: 45/255,
                                            blue: 45/255
                                        ), // #2D2D2D
                                        lineWidth: 1.2
                                    )
                            )
                            .cornerRadius(33)
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 42)
                }
            }
        }
    }
}

#Preview {
    Onb3()
}
