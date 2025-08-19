//
//  ContentView.swift
//  Clarity
//
//  Created by Craig Peters on 17/08/2025.
//

import SwiftUI

struct ContentView: View {
    //    @State private var tasks : [String] = ["Cuddle Socks", "Take Socks for Walk"]
    //    @State private var taskToAdd = ""

    var body: some View {
        TabView {
            Tab("Tasks", systemImage: "checkmark.square") {
                TaskIndexView()
            }
        }
    }
}

#Preview {
    ContentView()
}
