//
//  CategoryLines.swift
//  Clarity
//
//  Created by Craig Peters on 13/07/2026.
//

import SwiftUI


struct CategoryLines: View {
    var categories: [Category] = []
    var body: some View {
        HStack(spacing: 0)
        {
            ForEach(categories, id: \.self) { category in
                Rectangle()
                    .fill(category.color!.SwiftUIColor)
            }
        }
    }
}

#Preview {
    CategoryLines(
        categories: PreviewData.shared.getCategories()
    )
    .modelContainer(PreviewData.shared.previewContainer)
}
