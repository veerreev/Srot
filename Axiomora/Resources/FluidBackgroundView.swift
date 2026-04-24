import UIKit

class FluidBackgroundView: UIView {

    private let blob1 = CAGradientLayer()
    private let blob2 = CAGradientLayer()

    // Pre-computed at setup so animateBlobColors() never recalculates them.
    private var normalColors1: [Any] = []
    private var normalColors2: [Any] = []
    private var brightColors1: [Any] = []
    private var brightColors2: [Any] = []

    private var isVerifying = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradients()
        setupObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradients()
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resumeAnimations),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func resumeAnimations() {
        startAnimations()
    }

    private func setupGradients() {
        let blue   = Theme.Colors.blobBlue
        let purple = Theme.Colors.blobPurple

        normalColors1 = [blue.cgColor,            UIColor.clear.cgColor]
        normalColors2 = [purple.cgColor,           UIColor.clear.cgColor]
        brightColors1 = [brighten(blue).cgColor,   UIColor.clear.cgColor]
        brightColors2 = [brighten(purple).cgColor, UIColor.clear.cgColor]

        blob1.type = .radial
        blob1.colors = normalColors1
        blob1.startPoint = CGPoint(x: 0.5, y: 0.5)
        blob1.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(blob1, at: 0)

        blob2.type = .radial
        blob2.colors = normalColors2
        blob2.startPoint = CGPoint(x: 0.5, y: 0.5)
        blob2.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(blob2, at: 1)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.width * 5
        blob1.frame = CGRect(x: 0, y: 0, width: size, height: size)
        blob2.frame = CGRect(x: 0, y: 0, width: size, height: size)

        startAnimations()
    }

    private func startAnimations() {
        if UIAccessibility.isReduceMotionEnabled { return }

        guard blob1.animation(forKey: "positionAnimation") == nil else { return }

        let w = bounds.width
        let h = bounds.height

        let topLeft     = CGPoint(x: 0, y: 0)
        let bottomLeft  = CGPoint(x: 0, y: h)
        let bottomRight = CGPoint(x: w, y: h)
        let topRight    = CGPoint(x: w, y: 0)

        let path1 = [topLeft, bottomLeft, bottomRight, topRight, topLeft]
        animatePosition(layer: blob1, points: path1, duration: 60)

        let path2 = [bottomRight, topRight, topLeft, bottomLeft, bottomRight]
        animatePosition(layer: blob2, points: path2, duration: 50)

        animateScale(layer: blob1, values: [1.0, 1.5, 0.8, 1.2, 1.0], duration: 37)
        animateScale(layer: blob2, values: [1.2, 0.7, 1.4, 0.9, 1.2], duration: 53)
    }

    private func animatePosition(layer: CALayer, points: [CGPoint], duration: CFTimeInterval) {
        let anim = CAKeyframeAnimation(keyPath: "position")
        anim.values = points.map { NSValue(cgPoint: $0) }
        anim.duration = duration
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        anim.calculationMode = .paced

        layer.add(anim, forKey: "positionAnimation")
    }

    private func animateScale(layer: CALayer, values: [CGFloat], duration: CFTimeInterval) {
        let anim = CAKeyframeAnimation(keyPath: "transform.scale")
        anim.values = values
        anim.duration = duration
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        anim.calculationMode = .cubic

        layer.add(anim, forKey: "scaleAnimation")
    }

    // MARK: - Verification Animation

    func startVerifyingAnimation() {
        guard !isVerifying else { return }
        isVerifying = true
        animateBlobColors(bright: true)
        setSpeed(5, on: blob1)
        setSpeed(5, on: blob2)
    }

    func stopVerifyingAnimation() {
        guard isVerifying else { return }
        isVerifying = false
        animateBlobColors(bright: false)
        setSpeed(1, on: blob1)
        setSpeed(1, on: blob2)
    }

    // Scales the animation timeline of a blob layer without a visual jump.
    // Works by preserving the layer's current local time across the speed change:
    // localTime = (parentTime − beginTime) × speed
    // Solving for the new beginTime that keeps localTime constant gives:
    // newBeginTime = currentMediaTime − currentLocalTime / newSpeed
    private func setSpeed(_ newSpeed: Float, on blobLayer: CALayer) {
        let currentLocalTime = blobLayer.convertTime(CACurrentMediaTime(), from: nil)
        blobLayer.speed = newSpeed
        blobLayer.timeOffset = 0
        blobLayer.beginTime = CACurrentMediaTime() - Double(currentLocalTime) / Double(newSpeed)
    }

    // Smoothly cross-fades the blob gradient colours between normal and bright.
    // CAGradientLayer.colors is implicitly animatable, so wrapping the mutation
    // in a CATransaction is all that's needed.
    private func animateBlobColors(bright: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.8)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        blob1.colors = bright ? brightColors1 : normalColors1
        blob2.colors = bright ? brightColors2 : normalColors2
        CATransaction.commit()
    }

    // Boosts RGB channels and alpha to simulate increased luminosity.
    // getRed works across all standard sRGB-based UIColors.
    private func brighten(_ color: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return color }
        return UIColor(
            red:   min(r * 1.4, 1.0),
            green: min(g * 1.4, 1.0),
            blue:  min(b * 1.4, 1.0),
            alpha: min(a * 1.6, 1.0)
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
