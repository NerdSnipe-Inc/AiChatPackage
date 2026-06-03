import SwiftUI

struct DemoRow: View {
    let demo: Demo

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: demo.systemImage)
                .frame(width: 20)
                .foregroundStyle(providerColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(demo.title)
                    .font(.body)
                Text(demo.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let badge = demo.badge {
                Spacer()
                Text(badge)
                    .font(.caption2.monospaced())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(providerColor.opacity(0.12), in: .capsule)
                    .foregroundStyle(providerColor)
            }
        }
        .padding(.vertical, 2)
    }

    private var providerColor: Color {
        switch demo.provider {
        case .openai:           .green
        case .anthropic:        .orange
        case .llamaServer:      .blue
        case .llamaLocal:       .purple
        case .mlx:              .teal
        case .foundationModels: .pink
        }
    }
}
