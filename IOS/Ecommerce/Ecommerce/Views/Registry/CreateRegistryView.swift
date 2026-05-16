import SwiftUI

struct CreateRegistryView: View {
    @ObservedObject var viewModel: RegistryViewModel
    
    @State private var eventType = "Wedding"
    @State private var eventDate = Date()
    @State private var isPublic = true
    
    let eventTypes = ["Wedding", "Housewarming", "Birthday", "Baby Shower", "Other"]
    
    var body: some View {
        Form {
            Section(header: Text("Event Details")) {
                Picker("Event Type", selection: $eventType) {
                    ForEach(eventTypes, id: \.self) {
                        Text($0)
                    }
                }
                DatePicker("Event Date", selection: $eventDate, displayedComponents: .date)
            }
            
            Section(header: Text("Privacy")) {
                Toggle("Make Registry Public", isOn: $isPublic)
                Text(isPublic ? "Your registry will be searchable by guests." : "Your registry will be hidden and only accessible via a direct link.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Button {
                Task {
                    await viewModel.createRegistry(eventType: eventType, eventDate: eventDate, isPublic: isPublic)
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("Create Registry")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
    }
}
