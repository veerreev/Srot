//
//  ContentView.swift
//  SwiftUIFirstProject
//
//  Created by GEU on 09/02/26.
//

import SwiftUI

struct ContentView: View {
    @State var count: Int = 0
    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") {
                count += 1
            }
        }
    }
}

#Preview {
    ContentView()
}
