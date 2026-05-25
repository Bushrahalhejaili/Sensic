//
//  Onb2.swift
//  Sensic
//
//  Created by راما بدر بن جامع on 02/12/1447 AH.
//
import SwiftUI

struct Onb2: View {
    
    @State private var showHome = false
    @State private var showOnb3 = false
    
    var body: some View {
        
        if showHome {
            
            HomeView()
            
        } else if showOnb3 {
            
            Onb3()
            
        } else {
            
            ZStack {
                
                // Background
                Image("Onb")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack {
                    
                    // Skip
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            showHome = true
                        }) {
                            Text("Skip")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 10)

                    Spacer()
                    
                    // Title
                    VStack(spacing: -2) {
                        
                        Text("Each instrument")
                            .font(.custom("Arial Hebrew", size: 32))
                            .foregroundColor(.white)
                        
                        Text("has its own")
                            .font(.custom("Arial Hebrew", size: 32))
                            .foregroundColor(.white)
                        
                        Text("haptic feeling")
                            .font(.custom("Arial Hebrew", size: 32))
                            .foregroundColor(
                                Color(
                                    red: 50/255,
                                    green: 125/255,
                                    blue: 218/255
                                ) // #327DDA
                            )
                    }
                    .multilineTextAlignment(.center)
                   
                    .offset(y: 205)

                    Spacer()

                    // Dots
                    HStack(spacing: 8) {
                        
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 10, height: 10)
                   
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                        
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 10, height: 10)
                    }
                    .padding(.bottom, 34)

                    // Next Button
                    Button(action: {
                        showOnb3 = true
                    }) {
                        Text("Next")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                Color(
                                    red: 14/255,
                                    green: 15/255,
                                    blue: 38/255
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 33)
                                    .stroke(
                                        Color(
                                            red: 45/255,
                                            green: 45/255,
                                            blue: 45/255
                                        ),
                                        lineWidth: 1.2
                                    )
                            )
                            .cornerRadius(33)
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

#Preview {
    Onb2()
}
