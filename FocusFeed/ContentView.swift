//
//  ContentView.swift
//  FocusFeed
//
//  Created by Timo Kuehne on 19.01.26.
//

import SwiftUI

struct ContentView: View {
    @State private var filterManager = FilterManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Status indicator
                VStack(spacing: 12) {
                    Image(systemName: filterManager.isEnabled ? "shield.checkered" : "shield.slash")
                        .font(.system(size: 64))
                        .foregroundStyle(filterManager.isEnabled ? .green : .secondary)
                        .animation(.easeInOut, value: filterManager.isEnabled)

                    Text(filterManager.status)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Main toggle
                VStack(spacing: 8) {
                    Toggle("Block YouTube Shorts", isOn: Binding(
                        get: { filterManager.isEnabled },
                        set: { _ in
                            Task {
                                await filterManager.toggleFilter()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .disabled(filterManager.isLoading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if filterManager.isLoading {
                        ProgressView()
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal)

                // Info section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Blocked Patterns")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        PatternRow(pattern: "/shorts/", description: "Short video pages")
                        PatternRow(pattern: "/youtubei/v1/reel/", description: "Reel API endpoints")
                        PatternRow(pattern: "el=shortspage", description: "Shorts page parameter")
                        PatternRow(pattern: "reel_watch_sequence", description: "Reel sequences")
                        PatternRow(pattern: "reel_item_watch", description: "Reel items")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                // Footer
                Text("Uses iOS 26 URL Filter API to block requests system-wide")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("FocusFeed")
        }
    }
}

struct PatternRow: View {
    let pattern: String
    let description: String

    var body: some View {
        HStack {
            Text(pattern)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer()

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
