import SwiftUI

struct SearchFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SearchViewModel
    
    // Local state to hold slider values before applying
    @State private var priceValue: Double = 500
    
    var body: some View {
        NavigationView {
            Form {
                if !viewModel.availableCategories.isEmpty {
                    Section(header: Text("Category")) {
                        Picker("Category", selection: $viewModel.selectedCategory) {
                            Text("All").tag(String?.none)
                            ForEach(viewModel.availableCategories, id: \.self) { category in
                                Text(category).tag(String?.some(category))
                            }
                        }
                    }
                }
                
                Section(header: Text("Max Price: $\(Int(priceValue))")) {
                    Slider(value: $priceValue, in: 0...1000, step: 10)
                        .onChange(of: priceValue) { oldValue, newValue in
                            viewModel.maxPrice = newValue == 1000 ? nil : newValue
                        }
                }
                
                if !viewModel.availableTags.isEmpty {
                    Section(header: Text("Tags")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.availableTags, id: \.self) { tag in
                                    SearchChipView(
                                        title: tag.capitalized,
                                        isSelected: viewModel.selectedTags.contains(tag)
                                    ) {
                                        viewModel.toggleTag(tag)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section {
                    Button("Clear Filters") {
                        viewModel.clearFilters()
                        priceValue = 1000
                        viewModel.applyFilters()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.applyFilters()
                        dismiss()
                    }
                }
            }
            .onAppear {
                priceValue = viewModel.maxPrice ?? 1000
            }
        }
    }
}
