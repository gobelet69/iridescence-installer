import SwiftUI
import AppKit

/// Canonical mathematically consistent pixel-grid canvas for Iridescence headers and cards.
/// Discrete integer grid cells (`cellSize = 8pt`, dot radius = 1.2pt).
public struct PixelGridHeader: View {
    let title: String
    let subtitle: String?
    let accentColor: Color

    @State private var illuminatedCells: Set<GridPoint> = []
    @State private var starCells: [GridPoint: Color] = [:]
    @State private var timer: Timer?

    private let cellSize: CGFloat = 8
    private let dotRadius: CGFloat = 1.2

    public init(title: String, subtitle: String? = nil, accentColor: Color = IridescenceTheme.luminousCyan) {
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // Mathematical background grid canvas
            GeometryReader { proxy in
                Canvas { context, size in
                    let cols = Int(size.width / cellSize)
                    let rows = Int(size.height / cellSize)

                    // Draw subtle grid dots
                    for col in 0..<cols {
                        for row in 0..<rows {
                            let pt = GridPoint(col: col, row: row)
                            let rect = CGRect(
                                x: CGFloat(col) * cellSize + (cellSize - dotRadius * 2) / 2,
                                y: CGFloat(row) * cellSize + (cellSize - dotRadius * 2) / 2,
                                width: dotRadius * 2,
                                height: dotRadius * 2
                            )

                            if let starColor = starCells[pt] {
                                // 5-cell pixel cross star center
                                context.fill(Path(rect), with: .color(starColor))
                            } else if illuminatedCells.contains(pt) {
                                // Subtly illuminated signal dot
                                context.fill(Path(rect), with: .color(accentColor.opacity(0.85)))
                            } else {
                                // Restrained baseline grid dot
                                context.fill(Path(rect), with: .color(IridescenceTheme.hairline.opacity(0.35)))
                            }
                        }
                    }
                }
                .onAppear {
                    setupInitialMatrix(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .frame(height: 72)
            .clipped()

            // Header typography
            HStack(spacing: 12) {
                // Wordmark icon / glyph
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(IridescenceTheme.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(IridescenceTheme.hairline, lineWidth: 1)
                        )
                        .frame(width: 36, height: 36)

                    // Mini pixel star emblem
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        Text("111")
                            .font(IridescenceTheme.fontMono(size: 10, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(IridescenceTheme.electricBlue.opacity(0.15))
                            .foregroundColor(IridescenceTheme.electricBlue)
                            .clipShape(Capsule())
                    }

                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundColor(IridescenceTheme.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 72)
        .background(IridescenceTheme.surfaceSubtle.opacity(0.5))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(IridescenceTheme.hairline),
            alignment: .bottom
        )
    }

    private func setupInitialMatrix(width: CGFloat, height: CGFloat) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }

        let cols = max(1, Int(width / cellSize))
        let rows = max(1, Int(height / cellSize))

        // Deterministic discrete pixel points
        var newStars: [GridPoint: Color] = [:]
        if cols > 10 && rows > 3 {
            newStars[GridPoint(col: cols - 4, row: 2)] = IridescenceTheme.luminousCyan
            newStars[GridPoint(col: cols - 12, row: 5)] = IridescenceTheme.magenta
            newStars[GridPoint(col: cols - 8, row: 3)] = IridescenceTheme.ultraviolet
        }
        self.starCells = newStars

        var initialIlluminated: Set<GridPoint> = []
        for _ in 0..<8 {
            let col = Int.random(in: 0..<cols)
            let row = Int.random(in: 0..<rows)
            initialIlluminated.insert(GridPoint(col: col, row: row))
        }
        self.illuminatedCells = initialIlluminated
    }
}

public struct GridPoint: Hashable, Sendable {
    public let col: Int
    public let row: Int
}
