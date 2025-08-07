import SwiftUI
import Combine
import Foundation

struct LinkView: View {
    @StateObject private var linkViewModel = LinkViewModel()
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(toolbarActiveImageColor)
                        Text("Back")
                            .foregroundColor(toolbarActiveFontColor)
                        Spacer()
                        Text("Links")
                            .foregroundColor(sectionHeaderColor)
                            .bold()
                    }
                }
                .padding()
                Spacer()
            }
            .background(toolbarBackgroundColor)
        }

        Group {
            if linkViewModel.isLoading {
                loadingView
            } else if linkViewModel.sortedGroupedLinks().isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .onAppear {
            linkViewModel.fetchLinks()
        }
        .sheet(isPresented: $showWebView) {
            if let url = externalURL {
                SafariView(url: url)
                    .setSheetConfig()
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            Text("No links available")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding()
            Spacer()
        }
    }

    private var contentView: some View {
        
        List {
            ForEach(linkViewModel.sortedGroupedLinks(), id: \.0) { category, items in
                Section(header:
                    Text(category)
                        .font(.subheadline)
                        .foregroundColor(sectionHeaderColor)
                        .bold()
                ) {
                    ForEach(items) { item in
                        Button(action: {
                            if let url = URL(string: item.link) {
                                externalURL = url
                                showWebView = true
                            }
                        }) {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundColor(rowHeaderColor)
                                Text(item.description)
                                    .font(.footnote)
                                    .foregroundColor(rowTextColor)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    // Open URL in in-app Safari view
    func openLink(_ url: URL) {
        externalURL = url
        showWebView = true
    }
}
