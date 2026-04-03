//
//  ChipFlowView.swift
//  Axiomora
//
//  Created by Veer on 03/04/26.
//

import UIKit

final class ChipFlowView: UIView {

    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    private var chipViews: [ChipView] = []

    // MARK: - API

    func configure(with handles: [SocialHandle]) {
        chipViews.forEach { $0.removeFromSuperview() }
        chipViews = handles.map { ChipView(platform: $0.platform, handle: $0.userInput) }
        chipViews.forEach { addSubview($0) }
        setNeedsLayout()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        layout(in: bounds.width, apply: true)
    }

    @discardableResult
    private func layout(in containerWidth: CGFloat, apply: Bool) -> CGSize {
        guard containerWidth > 0 else { return .zero }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for chip in chipViews {
            let size = chip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x + size.width > containerWidth, x > 0 {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            if apply {
                chip.frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
            }
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: containerWidth,
                      height: chipViews.isEmpty ? 0 : y + rowHeight)
    }
}
