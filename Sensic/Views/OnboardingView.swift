import SwiftUI

struct OnboardingView: View {
    
    @State private var showHome = false
    @State private var showOnb2 = false
    
    var body: some View {
        
        if showHome {
            
            HomeView()
            
        } else if showOnb2 {
            
            Onb2()
            
        } else {
            
            ZStack {
                
                // Background
                Image("Onp")
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
                        
                        Text("Create your music")
                            .font(.custom("Arial Hebrew", size: 32))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 0) {
                            
                            Text("with ")
                                .font(.custom("Arial Hebrew", size: 32))
                                .foregroundColor(.white)
                            
                            Text("touch, sound")
                                .font(.custom("Arial Hebrew", size: 32))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(
                                                red: 223/255,
                                                green: 81/255,
                                                blue: 236/255
                                            ), // #DF51EC
                                            
                                            Color(
                                                red: 155/255,
                                                green: 78/255,
                                                blue: 251/255
                                            ), // #9B4EFB
                                            
                                            Color(
                                                red: 55/255,
                                                green: 139/255,
                                                blue: 242/255
                                            ) // #378BF2
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        
                        Text("and visuals.")
                            .font(.custom("Arial Hebrew", size: 32))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(
                                            red: 223/255,
                                            green: 81/255,
                                            blue: 236/255
                                        ),
                                        
                                        Color(
                                            red: 155/255,
                                            green: 78/255,
                                            blue: 251/255
                                        ),
                                        
                                        Color(
                                            red: 55/255,
                                            green: 139/255,
                                            blue: 242/255
                                        )
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .multilineTextAlignment(.center)
                    //  الرقم لتحريك الكلام
                    .offset(y: 205)
                    
                    Spacer()
                    HStack(spacing: 8) {
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                        
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 10, height: 10)
                        
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 10, height: 10)
                    }
                    .padding(.bottom, 34)
                    
                    // Next Button
                    Button(action: {
                        showOnb2 = true
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
    OnboardingView()
}
