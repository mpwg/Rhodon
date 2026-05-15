import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .font(DSTypography.body)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Rhodon")
    }
}
