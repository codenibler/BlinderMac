// Reusable format for the row that holds an app in blocked apps selector.
import SwiftUI

struct AppRow: View {
    let app: AppInfo
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        HStack {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .cornerRadius(4)
            } else {
                Image(systemName: "app.dashed")
                    .frame(width: 20, height: 20)
            }

            Text(app.name)
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle()) // clickable row
        .onTapGesture { toggle() }
    }
}
