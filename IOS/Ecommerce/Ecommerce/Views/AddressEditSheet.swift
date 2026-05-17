import SwiftUI

struct AddressEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var address: Address
    let onSave: (Address) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") { TextField("Home / Work", text: $address.label) }
                Section("Contact") {
                    TextField("Full name", text: $address.fullName)
                    TextField("Phone", text: $address.phone).keyboardType(.phonePad)
                }
                Section("Address") {
                    TextField("Line 1", text: $address.line1)
                    TextField("Line 2", text: $address.line2)
                    TextField("City", text: $address.city)
                    TextField("State", text: $address.state)
                    TextField("ZIP", text: $address.zip).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss(); onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { dismiss(); onSave(address) }.fontWeight(.semibold)
                }
            }
        }
    }
}
