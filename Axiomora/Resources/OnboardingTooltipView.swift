//
//  OnboardingTooltipView.swift
//  Axiomora
//

import UIKit

/// A callout bubble with a triangular arrow that points at a target view.
///
/// The arrow direction is decided automatically:
///   - If the target is in the top half of the screen → arrow points UP   (bubble below the button)
///   - If the target is in the bottom half            → arrow points DOWN  (bubble above the button)
///
/// Add to the view controller's root view (not the window) so coordinate
/// conversion stays simple.
final class OnboardingTooltipView: UIView {

    // MARK: - Layout constants
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding:   CGFloat = 12
    private let cornerRadius:      CGFloat = 12
    private let arrowHeight:       CGFloat = 10
    private let arrowWidth:        CGFloat = 18
    private let gap:               CGFloat = 10   // space between arrow tip and target edge

    // MARK: - Subviews
    private let label = UILabel()
    private let shapeLayer = CAShapeLayer()

    // Computed after layout
    private var arrowXOffsetInBubble: CGFloat = 0
    private var arrowOnTop: Bool = true           // true → arrow at top of box

    // MARK: - Factory

    /// Creates, positions, and adds the tooltip to `parentView`.
    /// Returns the tooltip so the caller can call `remove()` later.
    @discardableResult
    static func show(
        in parentView: UIView,
        pointingTo targetView: UIView,
        text: String
    ) -> OnboardingTooltipView {
        let tip = OnboardingTooltipView()
        tip.build(text: text, targetView: targetView, parentView: parentView)
        parentView.addSubview(tip)
        tip.animateIn()
        return tip
    }

    // MARK: - Public

    func remove(animated: Bool = true) {
        guard animated else { removeFromSuperview(); return }
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
        }
    }

    // MARK: - Build

    private func build(text: String, targetView: UIView, parentView: UIView) {
        backgroundColor = .clear
        isUserInteractionEnabled = false

        // ── Label ──────────────────────────────────────────────────────────
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.numberOfLines = 0
        label.textAlignment = .center

        let maxBubbleWidth: CGFloat = min(220, parentView.bounds.width - 32)
        let maxLabelWidth = maxBubbleWidth - horizontalPadding * 2
        let labelSize = label.sizeThatFits(CGSize(width: maxLabelWidth, height: .infinity))

        let bubbleW = ceil(labelSize.width)  + horizontalPadding * 2
        let bubbleH = ceil(labelSize.height) + verticalPadding  * 2
        let totalH  = bubbleH + arrowHeight

        // ── Decide arrow direction based on target position ────────────────
        let targetFrameInParent = targetView.convert(targetView.bounds, to: parentView)
        arrowOnTop = targetFrameInParent.midY < parentView.bounds.midY

        // ── Frame of the whole view (bubble + arrow) ───────────────────────
        var originX = targetFrameInParent.midX - bubbleW / 2
        originX = max(12, min(originX, parentView.bounds.width - bubbleW - 12))

        let originY: CGFloat
        if arrowOnTop {
            // Bubble sits below the target; arrow points up from the top edge
            originY = targetFrameInParent.maxY + gap
        } else {
            // Bubble sits above the target; arrow points down from the bottom edge
            originY = targetFrameInParent.minY - totalH - gap
        }

        frame = CGRect(x: originX, y: originY, width: bubbleW, height: totalH)

        // ── Arrow X offset relative to the bubble's left edge ─────────────
        // We want the arrow tip to align with the target button's centre X.
        let targetMidXInSelf = targetFrameInParent.midX - originX
        let minArrow = cornerRadius + arrowWidth / 2
        let maxArrow = bubbleW - cornerRadius - arrowWidth / 2
        arrowXOffsetInBubble = max(minArrow, min(targetMidXInSelf, maxArrow))

        // ── Label inside the bubble ────────────────────────────────────────
        let labelY: CGFloat = arrowOnTop
            ? arrowHeight + verticalPadding          // arrow is at top, label below it
            : verticalPadding                        // arrow is at bottom, label above it
        label.frame = CGRect(
            x: horizontalPadding,
            y: labelY,
            width: ceil(labelSize.width),
            height: ceil(labelSize.height)
        )
        addSubview(label)

        // ── Draw shape ─────────────────────────────────────────────────────
        layer.insertSublayer(shapeLayer, at: 0)
        shapeLayer.frame = bounds
        drawCallout(bubbleW: bubbleW, bubbleH: bubbleH)
    }

    // MARK: - Shape drawing

    private func drawCallout(bubbleW: CGFloat, bubbleH: CGFloat) {
        let path = UIBezierPath()
        let r    = cornerRadius
        let ax   = arrowXOffsetInBubble   // arrow centre X

        if arrowOnTop {
            // Arrow at the TOP, rounded rect below it
            //
            //        /\         ← arrow tip (points up toward the button)
            //       /  \
            //  ────/    \────────────────────
            // │                              │
            // │       label text             │
            // │                              │
            //  ──────────────────────────────
            let boxTop = arrowHeight   // the rounded rect starts below the arrow
            path.move(to: CGPoint(x: ax, y: 0))                                      // arrow tip
            path.addLine(to: CGPoint(x: ax + arrowWidth / 2, y: boxTop))             // arrow right foot
            path.addLine(to: CGPoint(x: bubbleW - r,         y: boxTop))             // top-right before corner
            path.addArc(withCenter: CGPoint(x: bubbleW - r, y: boxTop + r),
                        radius: r, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: bubbleW, y: boxTop + bubbleH - r))           // right edge
            path.addArc(withCenter: CGPoint(x: bubbleW - r, y: boxTop + bubbleH - r),
                        radius: r, startAngle: 0, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: r, y: boxTop + bubbleH))                     // bottom edge
            path.addArc(withCenter: CGPoint(x: r, y: boxTop + bubbleH - r),
                        radius: r, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: 0, y: boxTop + r))                           // left edge
            path.addArc(withCenter: CGPoint(x: r, y: boxTop + r),
                        radius: r, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: ax - arrowWidth / 2, y: boxTop))             // arrow left foot
            path.close()                                                              // back to arrow tip

        } else {
            // Arrow at the BOTTOM, rounded rect above it
            //
            //  ──────────────────────────────
            // │                              │
            // │       label text             │
            // │                              │
            //  ────────────────\    /────────
            //                   \  /
            //                    \/          ← arrow tip (points down toward the button)
            let boxBottom = bubbleH
            path.move(to: CGPoint(x: r, y: 0))                                       // top-left after corner
            path.addLine(to: CGPoint(x: bubbleW - r, y: 0))
            path.addArc(withCenter: CGPoint(x: bubbleW - r, y: r),
                        radius: r, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: bubbleW, y: boxBottom - r))
            path.addArc(withCenter: CGPoint(x: bubbleW - r, y: boxBottom - r),
                        radius: r, startAngle: 0, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: ax + arrowWidth / 2, y: boxBottom))          // bottom right before arrow
            path.addLine(to: CGPoint(x: ax, y: boxBottom + arrowHeight))             // arrow tip
            path.addLine(to: CGPoint(x: ax - arrowWidth / 2, y: boxBottom))          // bottom left after arrow
            path.addLine(to: CGPoint(x: r, y: boxBottom))
            path.addArc(withCenter: CGPoint(x: r, y: boxBottom - r),
                        radius: r, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: 0, y: r))
            path.addArc(withCenter: CGPoint(x: r, y: r),
                        radius: r, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
            path.close()
        }

        shapeLayer.path        = path.cgPath
        shapeLayer.fillColor   = UIColor(red: 0.07, green: 0.07, blue: 0.12, alpha: 0.92).cgColor
        shapeLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7).cgColor
        shapeLayer.lineWidth   = 1.5

        // Subtle drop shadow so the bubble floats over the camera preview
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOffset  = CGSize(width: 0, height: 3)
        layer.shadowRadius  = 8
        layer.shadowOpacity = 0.45
    }

    // MARK: - Animation

    private func animateIn() {
        alpha     = 0
        transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(
            withDuration: 0.45,
            delay: 0.15,          // slight delay so it appears after the glow settles
            usingSpringWithDamping: 0.65,
            initialSpringVelocity: 0.4
        ) {
            self.alpha     = 1
            self.transform = .identity
        }
    }
}
