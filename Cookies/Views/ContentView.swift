//
//  ContentView.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        CookiesDashboardView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(TimeAllowanceManager())
}
