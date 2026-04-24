//
//  ScannerOverlayView.swift
//  Axiomora
//
//  Created by Veer on 24/04/26.
//


import UIKit

class ScannerOverlayView: UIView {

    // MARK: - Sublayers

    /// Dims the image behind the scanner.
    private let dimView = UIView()

    /// Parent layer for the scan line — animating this moves the glow
    /// and the bright centre line together as a single unit.
    private let scanGroup = CALayer()

    /// Soft vertical glow gradient that surrounds the bright centre line.
    private let scanGlowLayer = CAGradientLayer()

    /// The crisp, bright neon centre line.
    private let scanLineLayer = CALayer()

    /// The four corner brackets drawn as a single shape layer.
    private let bracketsLayer = CAShapeLayer()

    // MARK: - Constants

    private let glowHeight:   CGFloat       = 60
    private let lineHeight:   CGFloat       = 2
    private let bracketArm:   CGFloat       = 22
    private let scanDuration: CFTimeInterval = 1.8

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        clipsToBounds = true
        backgroundColor = .clear
        isHidden = true

        setupDimView()
        setupBracketsLayer()
        setupScanGroup()
    }

    private func setupDimView() {
        dimView.backgroundColor = .black
        dimView.alpha = 0
        addSubview(dimView)
    }

    private func setupBracketsLayer() {
        bracketsLayer.strokeColor   = UIColor.systemBlue.cgColor
        bracketsLayer.fillColor     = UIColor.clear.cgColor
        bracketsLayer.lineWidth     = 2
        bracketsLayer.lineCap       = .square
        // Neon glow on the brackets
        bracketsLayer.shadowColor   = UIColor.systemBlue.cgColor
        bracketsLayer.shadowRadius  = 8
        bracketsLayer.shadowOpacity = 1
        bracketsLayer.shadowOffset  = .zero
        layer.addSublayer(bracketsLayer)
    }

    private func setupScanGroup() {
        // Vertical gradient: fully transparent edges → soft blue glow → bright cyan-white peak
        scanGlowLayer.type       = .axial
        scanGlowLayer.startPoint = CGPoint(x: 0.5, y: 0)
        scanGlowLayer.endPoint   = CGPoint(x: 0.5, y: 1)
        scanGlowLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.systemBlue.withAlphaComponent(0.08).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.55).cgColor,
            UIColor(red: 0.55, green: 0.88, blue: 1.0, alpha: 1.0).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.55).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.08).cgColor,
            UIColor.clear.cgColor
        ]
        scanGlowLayer.locations = [0, 0.18, 0.38, 0.5, 0.62, 0.82, 1.0]

        // Crisp centre line — the shadow provides the extra neon bloom
        scanLineLayer.backgroundColor = UIColor(red: 0.7, green: 0.93, blue: 1.0, alpha: 1.0).cgColor
        scanLineLayer.shadowColor     = UIColor.systemBlue.cgColor
        scanLineLayer.shadowRadius    = 6
        scanLineLayer.shadowOpacity   = 1
        scanLineLayer.shadowOffset    = .zero

        scanGroup.addSublayer(scanGlowLayer)
        scanGroup.addSublayer(scanLineLayer)
        layer.addSublayer(scanGroup)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        dimView.frame = bounds

        bracketsLayer.frame = bounds
        bracketsLayer.path  = makeBracketPath()

        let w = bounds.width

        // scanGroup starts at the top: position.y = glowHeight/2 (centre of the layer)
        scanGroup.frame      = CGRect(x: 0, y: 0, width: w, height: glowHeight)
        scanGlowLayer.frame  = CGRect(x: 0, y: 0, width: w, height: glowHeight)
        scanLineLayer.frame  = CGRect(x: 0,
                                      y: (glowHeight - lineHeight) / 2,
                                      width: w,
                                      height: lineHeight)
    }

    // MARK: - Bracket path

    private func makeBracketPath() -> CGPath {
        let w   = bounds.width
        let h   = bounds.height
        let arm = bracketArm
        let path = UIBezierPath()

        // Top-left
        path.move(to:    CGPoint(x: 0,       y: arm))
        path.addLine(to: CGPoint(x: 0,       y: 0))
        path.addLine(to: CGPoint(x: arm,     y: 0))

        // Top-right
        path.move(to:    CGPoint(x: w - arm, y: 0))
        path.addLine(to: CGPoint(x: w,       y: 0))
        path.addLine(to: CGPoint(x: w,       y: arm))

        // Bottom-left
        path.move(to:    CGPoint(x: 0,       y: h - arm))
        path.addLine(to: CGPoint(x: 0,       y: h))
        path.addLine(to: CGPoint(x: arm,     y: h))

        // Bottom-right
        path.move(to:    CGPoint(x: w - arm, y: h))
        path.addLine(to: CGPoint(x: w,       y: h))
        path.addLine(to: CGPoint(x: w,       y: h - arm))

        return path.cgPath
    }

    // MARK: - Public API

    func startScanning() {
        isHidden = false

        UIView.animate(withDuration: 0.35) {
            self.dimView.alpha = 0.45
        }

        guard bounds.height > 0 else { return }

        // Animate the scan group's vertical centre from the top to the bottom and back.
        // position.y is the layer's centre, so glowHeight/2 = top edge flush with view top.
        let anim = CABasicAnimation(keyPath: "position.y")
        anim.fromValue      = glowHeight / 2
        anim.toValue        = bounds.height - glowHeight / 2
        anim.duration       = scanDuration
        anim.autoreverses   = true
        anim.repeatCount    = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        scanGroup.add(anim, forKey: "scan")
    }

    func stopScanning(completion: (() -> Void)? = nil) {
        scanGroup.removeAnimation(forKey: "scan")

        UIView.animate(withDuration: 0.35, animations: {
            self.dimView.alpha = 0
        }) { _ in
            self.isHidden = true
            // Silently reset to top so the next startScanning() begins from there
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.scanGroup.position.y = self.glowHeight / 2
            CATransaction.commit()
            completion?()
        }
    }
}
