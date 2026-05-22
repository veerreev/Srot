//
//  ScannerOverlayView.swift
//  Axiomora
//
//  Created by Veer on 24/04/26.
//

import UIKit
import CoreImage

final class ScannerOverlayView: UIView {

    private let blurredImageView = UIImageView()
    private let dimView = UIView()
    private let tintView = UIView()
    private let dotContainerLayer = CALayer()

    private let dotColor : UIColor = .systemBlue
    private let overlayTintColor : UIColor = .systemBlue.withAlphaComponent(0.06)
    private let dimAlpha: CGFloat = 0.7
    private let blurRadius: CGFloat = 5.5
    private let ciContext = CIContext(options: nil)
    private let dotSize: CGFloat = 4.5
    private let minimumColumnCount = 8
    private let minimumRowCount = 12
    private let targetHorizontalSpacing: CGFloat = 24
    private let targetVerticalSpacing: CGFloat = 22
    private let rowWaveDuration: CFTimeInterval = 0.95
    private let rowWaveStep: CFTimeInterval = 0.12
    private let baseDotOpacity: Float = 0.26
    private let highlightedDotOpacity: Float = 0.95
    private let highlightedDotScale: CGFloat = 2.3

    private var isScanning = false
    private var lastRenderedSize: CGSize = .zero
    private var sourceImage: UIImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true
        backgroundColor = .clear
        isHidden = true

        blurredImageView.contentMode = .scaleAspectFill
        blurredImageView.clipsToBounds = true
        blurredImageView.isUserInteractionEnabled = false
        blurredImageView.alpha = 0
        addSubview(blurredImageView)

        dimView.backgroundColor = Theme.Colors.black
        dimView.alpha = 0
        dimView.isUserInteractionEnabled = false
        addSubview(dimView)

        tintView.backgroundColor = overlayTintColor
        tintView.alpha = 0
        tintView.isUserInteractionEnabled = false
        addSubview(tintView)

        dotContainerLayer.opacity = 0
        layer.addSublayer(dotContainerLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        blurredImageView.frame = bounds
        dimView.frame = bounds
        tintView.frame = bounds
        dotContainerLayer.frame = bounds

        guard isScanning, bounds.size != lastRenderedSize else { return }
        renderDotMatrix(animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func setSourceImage(_ image: UIImage?) {
        sourceImage = image
        blurredImageView.image = image.map(makeBlurredImage)
    }

    func startScanning(with image: UIImage? = nil) {
        guard !isScanning else { return }

        if let image {
            setSourceImage(image)
        } else if blurredImageView.image == nil, let sourceImage {
            blurredImageView.image = makeBlurredImage(from: sourceImage)
        }

        isScanning = true
        isHidden = false

        blurredImageView.alpha = 0
        dimView.alpha = 0
        tintView.alpha = 0
        dotContainerLayer.opacity = 0

        renderDotMatrix(animated: !UIAccessibility.isReduceMotionEnabled)

        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut]) {
            self.blurredImageView.alpha = 1
            self.dimView.alpha = self.dimAlpha
            self.tintView.alpha = 1
            self.dotContainerLayer.opacity = 1
        }
    }

    func stopScanning(completion: (() -> Void)? = nil) {
        guard isScanning else {
            completion?()
            return
        }

        isScanning = false
        dotContainerLayer.sublayers?.forEach { $0.removeAllAnimations() }

        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut], animations: {
            self.blurredImageView.alpha = 0
            self.dimView.alpha = 0
            self.tintView.alpha = 0
            self.dotContainerLayer.opacity = 0
        }) { _ in
            self.dotContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
            self.lastRenderedSize = .zero
            self.isHidden = true
            completion?()
        }
    }

    private func renderDotMatrix(animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        lastRenderedSize = bounds.size
        dotContainerLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let columnCount = max(minimumColumnCount, Int(bounds.width / targetHorizontalSpacing))
        let rowCount = max(minimumRowCount, Int(bounds.height / targetVerticalSpacing))
        let spacingX = bounds.width / CGFloat(columnCount + 1)
        let spacingY = bounds.height / CGFloat(rowCount + 1)
        let totalWaveDuration = Double(max(rowCount - 1, 0)) * rowWaveStep + rowWaveDuration

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for row in 0..<rowCount {
            let rowLayer = makeRowLayer(
                rowIndex: row,
                columnCount: columnCount,
                spacingX: spacingX,
                spacingY: spacingY
            )
            dotContainerLayer.addSublayer(rowLayer)

            guard animated else { continue }

            addWaveAnimation(
                to: rowLayer,
                rowIndex: row,
                totalDuration: totalWaveDuration
            )
        }

        CATransaction.commit()
    }

    private func makeRowLayer(
        rowIndex: Int,
        columnCount: Int,
        spacingX: CGFloat,
        spacingY: CGFloat
    ) -> CALayer {
        let rowLayer = CALayer()
        rowLayer.frame = bounds
        rowLayer.opacity = 1

        let y = spacingY * CGFloat(rowIndex + 1)

        for column in 0..<columnCount {
            let x = spacingX * CGFloat(column + 1)
            let dotLayer = CALayer()
            dotLayer.bounds = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
            dotLayer.position = CGPoint(x: x, y: y)
            dotLayer.backgroundColor = dotColor.cgColor
            dotLayer.cornerRadius = dotSize / 2
            dotLayer.borderWidth = 0.45
            dotLayer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
            dotLayer.shadowColor = dotColor.cgColor
            dotLayer.shadowOpacity = 0.06
            dotLayer.shadowRadius = 0.8
            dotLayer.shadowOffset = .zero
            dotLayer.opacity = baseDotOpacity
            rowLayer.addSublayer(dotLayer)
        }

        return rowLayer
    }

    private func addWaveAnimation(
        to layer: CALayer,
        rowIndex: Int,
        totalDuration: CFTimeInterval
    ) {
        let rowStart = Double(rowIndex) * rowWaveStep
        let rowPeak = rowStart + rowWaveDuration * 0.42
        let rowEnd = rowStart + rowWaveDuration
        let rowStartFraction = min(max(rowStart / totalDuration, 0), 0.98)
        let rowPeakFraction = min(max(rowPeak / totalDuration, rowStartFraction), 0.995)
        let rowEndFraction = min(max(rowEnd / totalDuration, rowPeakFraction), 0.999)

        let keyTimes: [NSNumber] = [
            0,
            NSNumber(value: rowStartFraction),
            NSNumber(value: rowPeakFraction),
            NSNumber(value: rowEndFraction),
            1
        ]

        layer.sublayers?.forEach { dotLayer in
            let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
            opacityAnimation.values = [
                baseDotOpacity,
                baseDotOpacity,
                highlightedDotOpacity,
                baseDotOpacity,
                baseDotOpacity
            ]
            opacityAnimation.keyTimes = keyTimes

            let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            scaleAnimation.values = [1, 1, highlightedDotScale, 1, 1]
            scaleAnimation.keyTimes = keyTimes

            let group = CAAnimationGroup()
            group.animations = [opacityAnimation, scaleAnimation]
            group.duration = totalDuration
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            group.isRemovedOnCompletion = false

            dotLayer.add(group, forKey: "rowWave")
        }
    }

    private func makeBlurredImage(from image: UIImage) -> UIImage {
        let normalizedImage = image.normalized()
        guard let ciImage = CIImage(image: normalizedImage) else { return normalizedImage }

        let clampedImage = ciImage.clampedToExtent()

        guard let blurFilter = CIFilter(name: "CIGaussianBlur"),
              let colorFilter = CIFilter(name: "CIColorControls") else {
            return normalizedImage
        }

        blurFilter.setValue(clampedImage, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)

        guard let blurredOutput = blurFilter.outputImage?.cropped(to: ciImage.extent) else {
            return normalizedImage
        }

        colorFilter.setValue(blurredOutput, forKey: kCIInputImageKey)
        colorFilter.setValue(0.96, forKey: kCIInputSaturationKey)
        colorFilter.setValue(1.02, forKey: kCIInputContrastKey)
        colorFilter.setValue(-0.01, forKey: kCIInputBrightnessKey)

        let finalImage = colorFilter.outputImage?.cropped(to: ciImage.extent) ?? blurredOutput

        guard let cgImage = ciContext.createCGImage(finalImage, from: ciImage.extent) else {
            return normalizedImage
        }

        return UIImage(cgImage: cgImage, scale: normalizedImage.scale, orientation: .up)
    }
}
