import SwiftUI

struct RegistryWizardView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var registryName = ""
    @State private var eventType = "Wedding"
    @State private var eventDate = Date()
    @State private var eventLocation = ""
    
    let eventTypes = [
        "Wedding (Western)",
        "Wedding (Indian)",
        "Engagement (Western)",
        "Engagement (Indian)",
        "Sangeet (Indian)",
        "Diwali Party (Indian)",
        "Casual Indian Gathering",
        "Western Dinner Party",
        "Brunch Party",
        "Housewarming",
        "Bridal Shower",
        "Baby Shower",
        "Birthday Party",
        "Dinner Gala",
        "Other"
    ]
    
    // Callback when created
    let onCreate: ((name: String, type: String, date: String, location: String)) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Registry Name (e.g. Sarah & David)", text: $registryName)
                        .font(.body)
                    
                    Picker("Event Type", selection: $eventType) {
                        ForEach(eventTypes, id: \.self) {
                            Text($0).font(.body)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("What are we celebrating?")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Section {
                    DatePicker("Event Date", selection: $eventDate, in: Date()..., displayedComponents: .date)
                        .font(.body)
                    
                    TextField("Location (Optional)", text: $eventLocation)
                        .font(.body)
                } header: {
                    Text("When and where?")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .navigationTitle("Create Registry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        let name = registryName.isEmpty ? "My Registry" : registryName
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MMM d, yyyy"
                        let dateString = formatter.string(from: eventDate)
                        
                        onCreate((
                            name: name + "'s " + eventType,
                            type: eventType,
                            date: dateString,
                            location: eventLocation
                        ))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .disabled(registryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
