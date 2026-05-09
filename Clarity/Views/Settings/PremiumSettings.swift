//
//  PremiumSettings.swift
//  Clarity
//
//  Created by Craig Peters on 04/05/2026.
//

import SwiftUI
import StoreKit

struct PremiumSettings: View {
    @Environment(Store.self) private var store: Store
    
    var body: some View {
        @Bindable var store = store
        VStack {
            StoreView(ids: ProductID.all)
                .storeButton(.hidden, for: .cancellation)
                .storeButton(.visible, for: .restorePurchases)
        }
        .padding()
    }
}

#Preview {
    @Previewable @Environment(Store.self) var store: Store
    PremiumSettings()
}
