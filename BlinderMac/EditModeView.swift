import SwiftUI

struct EditModeView: View {
    @EnvironmentObject var focusModel: FocusConfigModel

    var body: some View {
        if let id = focusModel.editingModeID,
           let idx = focusModel.modes.firstIndex(where: { $0.id == id }) {
            let binding = $focusModel.modes[idx]
            Form {
                TextField("Name", text: binding.name)
                // Editors for blocked apps/sites...
            }
            .padding()
        } else {
            Text("No mode selected to edit").padding()
        }
    }
}
