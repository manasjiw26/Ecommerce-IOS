import Foundation
import Combine
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var autocompleteResponse: AutocompleteResponse?
    @Published var searchResults: [Product] = []
    
    // Filtering state
    @Published var selectedCategory: String? = nil
    @Published var maxPrice: Double? = nil
    @Published var selectedTags: Set<String> = []
    
    // Loading states
    @Published var isSearching: Bool = false
    @Published var isAutocompleteLoading: Bool = false
    @Published var hasSearched: Bool = false
    
    // Pagination state
    @Published var currentPage: Int = 1
    @Published var hasMoreResults: Bool = false
    
    private var searchSubject = PassthroughSubject<(String, Int, Bool), Never>()
    private var lastUnfilteredResults: [Product] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let baseURL = Config.apiBaseURL + "/ai"
    private var deviceId: String {
        RecommendationEngine.shared.deviceId
    }
    
    init() {
        // Setup debounced autocomplete fetching
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.fetchAutocomplete(query: query)
            }
            .store(in: &cancellables)
            
        // Setup SwitchToLatest pipeline for Search API
        searchSubject
            .map { [weak self] (query, page, isLoadMore) -> AnyPublisher<([Product], Bool), Never> in
                guard let self = self, let url = URL(string: "\(self.baseURL)/search") else {
                    return Just(([], isLoadMore)).eraseToAnyPublisher()
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                var body: [String: Any] = [
                    "query": query,
                    "device_id": self.deviceId,
                    "page": page
                ]
                
                // Add server-side filters
                if let cat = self.selectedCategory { body["category"] = cat }
                if let mp = self.maxPrice { body["max_price"] = mp }
                if !self.selectedTags.isEmpty { body["tags"] = Array(self.selectedTags) }
                
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                
                return URLSession.shared.dataTaskPublisher(for: request)
                    .map(\.data)
                    .decode(type: [Product].self, decoder: JSONDecoder())
                    .map { ($0, isLoadMore) }
                    .replaceError(with: ([], isLoadMore))
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (products, isLoadMore) in
                guard let self = self else { return }
                self.isSearching = false
                
                if isLoadMore {
                    self.searchResults.append(contentsOf: products)
                } else {
                    self.searchResults = products
                    
                    // Cache the unfiltered results to maintain facet options in the filter sheet
                    if self.selectedCategory == nil && self.maxPrice == nil && self.selectedTags.isEmpty {
                        self.lastUnfilteredResults = products
                    }
                }
                
                self.hasMoreResults = products.count == 20
            }
            .store(in: &cancellables)
            
        // Reset state when search is cleared
        $searchText
            .filter { $0.isEmpty }
            .sink { [weak self] _ in
                self?.searchResults = []
                self?.hasSearched = false
                self?.clearFilters()
            }
            .store(in: &cancellables)
            
        // Force an initial fetch for empty state trending searches
        fetchAutocomplete(query: "")
    }
    
    // MARK: - Autocomplete
    
    private func fetchAutocomplete(query: String) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/autocomplete?q=\(encodedQuery)&device_id=\(deviceId)") else {
            return
        }
        
        isAutocompleteLoading = true
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: AutocompleteResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isAutocompleteLoading = false
                if case .failure(let error) = completion {
                    print("Autocomplete error: \(error)")
                }
            }, receiveValue: { [weak self] response in
                self?.autocompleteResponse = response
                self?.isAutocompleteLoading = false
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Search
    
    func performSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty { return }
        
        searchText = trimmedQuery
        isSearching = true
        hasSearched = true
        currentPage = 1
        
        // Notify AI bubble
        NotificationCenter.default.post(name: .aiSearchPerformed, object: nil, userInfo: ["query": trimmedQuery])
        
        // Trigger the Combine pipeline
        searchSubject.send((trimmedQuery, 1, false))
    }
    
    func loadMore() {
        guard hasMoreResults && !isSearching else { return }
        
        isSearching = true
        currentPage += 1
        searchSubject.send((searchText, currentPage, true))
    }
    
    // When filters change, we need to perform a new search
    func applyFilters() {
        guard !searchText.isEmpty else { return }
        performSearch(query: searchText)
    }
    
    // MARK: - Filtering
    
    var availableCategories: [String] {
        Array(Set(lastUnfilteredResults.compactMap { $0.category })).sorted()
    }
    
    var availableTags: [String] {
        let allTags = lastUnfilteredResults.compactMap { $0.tags }.flatMap { $0 }
        return Array(Set(allTags)).sorted()
    }
    
    func clearFilters() {
        selectedCategory = nil
        maxPrice = nil
        selectedTags.removeAll()
    }
    
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}
