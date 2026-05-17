import SwiftUI

struct RegistryWizardView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var registryName = ""
    @State private var eventType = "Wedding"
    @State private var customEventType = ""
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
    
    // Callback when created (date must be ISO: yyyy-MM-dd for API)
    let onCreate: ((name: String, type: String, isoDate: String, location: String)) -> Void
    
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

                    if eventType == "Other" {
                        TextField("Enter your event type", text: $customEventType)
                            .font(.body)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
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
                        let name = registryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = name.isEmpty ? "My Registry" : name
                        let isoDate = RegistryDateFormatter.isoDateString(from: eventDate)
                        let finalEventType: String = {
                            if eventType == "Other" {
                                let typed = customEventType.trimmingCharacters(in: .whitespacesAndNewlines)
                                return typed.isEmpty ? "Other" : typed
                            }
                            return eventType
                        }()
                        
                        onCreate((
                            name: finalName,
                            type: finalEventType,
                            isoDate: isoDate,
                            location: eventLocation
                        ))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .disabled({
                        if registryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
                        if eventType == "Other" && customEventType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
                        return false
                    }())
                }
            }
        }
    }
}
