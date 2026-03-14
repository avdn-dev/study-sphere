//
//  SessionHistoryRow.swift
//  StudySphere
//
//  Created by Yanlin Li  on 14/3/2026.
//

import SwiftUI

struct SessionHistoryRow: View {
  let entry: SessionHistoryEntry
  
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(entry.sessionName)
          .font(.subheadline.bold())
        Text(entry.date, style: .relative)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      
      Spacer()
      
      VStack(alignment: .trailing, spacing: 4) {
        Text(formattedDuration(entry.durationSeconds))
          .font(.subheadline.monospacedDigit())
        Text(String(format: "%.0f%% focus", entry.focusScore * 100))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 2)
  }
  
  private func formattedDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    if hours > 0 {
      return "\(hours)h \(minutes)m"
    } else {
      return "\(minutes)m"
    }
  }
}
