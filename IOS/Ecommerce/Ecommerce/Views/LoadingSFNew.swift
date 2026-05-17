import SwiftUI
import Combine

/// A minimalist, monochrome loading screen featuring a downsized SF Symbol carousel
/// with an expanded asset registry and ultra-clean spacing.
struct LoadingSFNew: View {
    // MARK: - Configuration
    // Expanded collection of clean, kitchen and dining focused assets
    let symbols = [
        "frying.pan.fill",
        "kettle.fill",
        "blender.fill",
        "cup.and.saucer.fill",
        "wineglass.fill",
        "chef.hat.fill",
        "teapot.fill",
        "fork.knife",
        "spoon.fill",
        "mug.fill",
        "carrot.fill",
        "birthday.cake.fill"
    ]
    
    @State private var activeIndex: Int = 0
    
    // Auto-advance carousel timer
    let timer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Pure, clean background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 50) {
                Spacer()
                
                // ── Centered Carousel ──
                ZStack {
                    ForEach(0..<symbols.count, id: \.self) { index in
                        let relativeOffset = CGFloat(index - activeIndex)
                        
                        Image(systemName: symbols[index])
                            .font(.system(size: 24, weight: .light)) // Downsized from 36 to 24
                            .foregroundColor(index == activeIndex ? .white : .white.opacity(0.18))
                            // Crisp magnification step for the active middle item
                            .scaleEffect(index == activeIndex ? 1.5 : 1.0)
                            // Tightened structural offset layout to match smaller footprint
                            .offset(x: relativeOffset * 54)
                            // Strict window filtering to fade peripheral items gracefully
                            .opacity(abs(relativeOffset) <= 2 ? 1.0 - (abs(relativeOffset) * 0.45) : 0)
                    }
                }
                .frame(height: 60)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: activeIndex)
                
                // ── Minimalist Text Anchor ──
                Text("LOADING")
                    .font(.system(size: 9, weight: .light))
                    .tracking(6)
                    .foregroundColor(.white.opacity(0.3))
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            // Clean loop logic through the expanded list
            activeIndex = (activeIndex + 1) % symbols.count
        }
    }
}

// MARK: - Preview
#Preview {
    LoadingSFNew()
}
