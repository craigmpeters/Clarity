//
//  ContentView.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TaskIndexView()
                .tabItem {
                    Image(systemName: "checkmark.square")
                    Text("Tasks")
                }
        }
    }
}

#Preview {
    ContentView()
}
