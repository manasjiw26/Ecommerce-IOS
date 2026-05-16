import SwiftUI

struct SearchEmptyStateView: View {
    let query: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No exact matches found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("We couldn't find anything matching \"\(query)\".\nTry checking for typos or using broader terms.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // This is where you could inject trending products or recommendations
            // as a fallback for the user.
        }
        .padding(.top, 60)
    }
}
