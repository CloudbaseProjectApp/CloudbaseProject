import SwiftUI

struct AreaForecastDiscussionView: View {
    @ObservedObject var viewModel: AFDViewModel
    @ObservedObject var userSettingsViewModel: UserSettingsViewModel
    let codeOptions: [(name:String,code:String)]
    @Binding var selectedIndex: Int
    let openLink: (URL) -> Void
    
    // local @State for which groups are expanded
    @State private var showKeyMessages = true
    @State private var showSynopsis    = true
    @State private var showDiscussion  = false
    @State private var showShortTerm   = false
    @State private var showLongTerm    = false
    @State private var showAviation    = true
    
    var body: some View {
        Section(header: Text("Area Forecast Discussion")
            .font(.headline)
            .foregroundColor(sectionHeaderColor)
            .bold()) {
                
                // Loading / No-codes cases
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.75)
                }
                else if codeOptions.isEmpty {
                    Text("No area forecast discussion found for region")
                }
                else {
                    
                    // If more than one airport code, show the picker
                    if codeOptions.count > 1 {
                        Picker("Select Location", selection: $selectedIndex) {
                            ForEach(0..<codeOptions.count, id: \.self) { idx in
                                Text(codeOptions[idx].name).tag(idx)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.vertical, 4)
                        .onChange(of: selectedIndex) { oldIndex, newIndex in
                            let code = codeOptions[newIndex].code
                            viewModel.fetchAFD(airportCode: code)
                            userSettingsViewModel.updatePickListSelection(pickListName: "afd", selectedIndex: newIndex)
                        }
                    }
                    
                    // Render the disclosure groups
                    if let afd = viewModel.AFDvar {
                        Text("Forecast Date: \(afd.date)")
                            .font(.footnote)
                        
                        buildGroup(label: "Key Messages",         isOn: $showKeyMessages,     content: afd.keyMessages)
                        buildGroup(label: "Synopsis",             isOn: $showSynopsis,        content: afd.synopsis)
                        buildGroup(label: "Discussion",           isOn: $showDiscussion,      content: afd.discussion)
                        buildGroup(label: "Short Term Forecast",  isOn: $showShortTerm,       content: afd.shortTerm)
                        buildGroup(label: "Long Term Forecast",   isOn: $showLongTerm,        content: afd.longTerm)
                        buildGroup(label: "Aviation Forecast",    isOn: $showAviation,        content: afd.aviation)
                    }
                    else {
                        // fallback if we don’t yet have AFDvar
                        ProgressView().scaleEffect(0.75)
                    }
                }
            }
    }
    
    // Helper to reduce duplication
    @ViewBuilder
    private func buildGroup(label: String,
                            isOn: Binding<Bool>,
                            content: String?) -> some View {
        if let text = content, !text.isEmpty {
            DisclosureGroup(isExpanded: isOn) {
                Text(text)
                    .font(.subheadline)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let base = AppURLManager.shared
                            .getAppURL(URLName: "areaForecastDiscussionURL"),
                              let url = URL(string: updateURL(url: base,
                                                              parameter: "airportcode",
                                                              value: codeOptions[selectedIndex].code))
                        else { return }
                        openLink(url)
                    }
            } label: {
                Text(label)
                    .font(.headline)
                    .foregroundColor(rowHeaderColor)
            }
        }
    }
}
