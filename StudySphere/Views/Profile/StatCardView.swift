//
//  StatCardView.swift
//  StudySphere
//
//  Created by Yanlin Li  on 14/3/2026.
//

import SwiftUI

struct StatCardView: View {
  let icon: String
  let value: String
  let label: String
  
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(.tint)
      Text(value)
        .font(.title3.bold())
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}

#Preview {
    StatCardView(icon: "pencil", value: "10", label: "Chicken")
}
