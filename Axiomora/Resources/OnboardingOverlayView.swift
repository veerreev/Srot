//
//  OnboardingOverlayView.swift
//  Axiomora
//

import UIKit

/// A full-screen overlay that dims everything except a target view,
/// draws a pulsing highlight ring around it, and shows a hint message.
///
/// Touches inside the spotlight are passed through to the underlying control;
/// all other touches are swallowed so the user can only interact with the
/// highlighted button.
final class OnboardingOverlayView: UIView {

    // MARK: - Private properties

    private weak var targetView: UIView?
    private let padding: CGFloat = 12
    private let pulseRingView = UIView()
    private let hintLabel = UILabel()
    private var targetFrame: CGRect = .zero   // in overlay coords

    // MARK: - Factory

    /// Adds an overlay to `window` that spotlights `targetView`.
    /// Returns the overlay so the caller can later call `remove()`.
    @discardableResult
    static func show(
        in window: UIWindow,
        targeting targetView: UIView,
        message: String
    ) -> OnboardingOverlayView {
        let overlay = OnboardingOverlayView(frame: window.bounds)
        overlay.targetView = targetView
        window.addSubview(overlay)
        overlay.buildUI(message: message)
        overlay.animateIn()
        overlay.startPulse()
        return overlay
    }

    // MARK: - Public

    func remove(animated: Bool = true) {
        guard animated else { removeFromSuperview(); return }
        UIView.animate(withDuration: 0.35, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
        }
    }

    // MARK: - Touch pass-through

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Touches inside the spotlight fall through to the button underneath.
        let paddedFrame = targetFrame.insetBy(dx: -padding, dy: -padding)
        if paddedFrame.contains(point) {
            return nil
        }
        // All other touches are absorbed by the overlay (blocks other buttons).
        return self
    }

    // MARK: - Build UI

    private func buildUI(message: String) {
        guard let targetView = targetView else { return }

        // Convert the target button's frame into our own coordinate space.
        // This works because we are already a subview of the window.
        targetFrame = targetView.convert(targetView.bounds, to: self)

        buildDimLayer()
        buildPulseRing(targetFrame: targetFrame, targetView: targetView)
        buildHintLabel(message: message, targetFrame: targetFrame)
    }

    /// Fills the screen with a dark layer that has a rounded-rect hole punched
    /// out around the highlighted button.
    private func buildDimLayer() {
        let dimView = UIView(frame: bounds)
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.70)
        addSubview(dimView)

        let cornerRadius = max(targetView?.layer.cornerRadius ?? 0, 8) + padding

        let fullPath = UIBezierPath(rect: bounds)
        let holePath = UIBezierPath(
            roundedRect: targetFrame.insetBy(dx: -padding, dy: -padding),
            cornerRadius: cornerRadius
        )
        fullPath.append(holePath)
        fullPath.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = fullPath.cgPath
        maskLayer.fillRule = .evenOdd
        dimView.layer.mask = maskLayer
    }

    /// Draws a rounded-rect ring around the spotlight that pulses.
    private func buildPulseRing(targetFrame: CGRect, targetView: UIView) {
        let cornerRadius = max(targetView.layer.cornerRadius, 8) + padding
        pulseRingView.frame = targetFrame.insetBy(dx: -padding, dy: -padding)
        pulseRingView.layer.cornerRadius = cornerRadius
        pulseRingView.layer.borderWidth = 2.5
        pulseRingView.layer.borderColor = UIColor.systemBlue.cgColor
        pulseRingView.backgroundColor = .clear
        pulseRingView.isUserInteractionEnabled = false
        addSubview(pulseRingView)
    }

    /// Positions an instruction label above or below the spotlight,
    /// depending on which half of the screen the button is in.
    private func buildHintLabel(message: String, targetFrame: CGRect) {
        hintLabel.text = message
        hintLabel.textColor = .white
        hintLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.layer.shadowColor = UIColor.black.cgColor
        hintLabel.layer.shadowOpacity = 0.8
        hintLabel.layer.shadowRadius = 4
        hintLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.isUserInteractionEnabled = false
        addSubview(hintLabel)

        // Place label above the spotlight if the button is in the lower half,
        // otherwise below it.
        let isInLowerHalf = targetFrame.midY > bounds.midY
        let labelCenterY: CGFloat

        if isInLowerHalf {
            // Label sits above the spotlight
            labelCenterY = targetFrame.minY - padding - 44
        } else {
            // Label sits below the spotlight
            labelCenterY = targetFrame.maxY + padding + 44
        }

        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: topAnchor, constant: labelCenterY),
            hintLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])
    }

    // MARK: - Animations

    private func animateIn() {
        alpha = 0
        UIView.animate(withDuration: 0.4) { self.alpha = 1 }
    }

    private func startPulse() {
        // Scale pulse
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 1.14
        scale.duration = 1.0
        scale.autoreverses = true
        scale.repeatCount = .infinity
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // Opacity pulse
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 1.0
        opacity.toValue = 0.35
        opacity.duration = 1.0
        opacity.autoreverses = true
        opacity.repeatCount = .infinity
        opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        pulseRingView.layer.add(scale, forKey: "pulseScale")
        pulseRingView.layer.add(opacity, forKey: "pulseOpacity")
    }
}
