//
//  InsightsView.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import SwiftUI

struct InsightsView: View {
    var body: some View {
        ActivityView()
    }
}

#Preview {
    InsightsView()
        .environmentObject(AuthViewModel())
        .environmentObject(TimeAllowanceManager())
        .environmentObject(ScreenTimeManager())
        .environmentObject(UserProfileManager())
}
