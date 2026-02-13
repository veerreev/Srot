import UIKit

class FluidBackgroundView: UIView {
    
    private let blob1 = CAGradientLayer()
    private let blob2 = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradients()
        setupObservers() // Add this
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradients()
        setupObservers() // Add this
    }
    
    // 1. Listen for the app returning to the foreground
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resumeAnimations),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    // 2. Restart animations when the app is reopened
    @objc private func resumeAnimations() {
        startAnimations()
    }

    private func setupGradients() {
        // ... (Keep your existing setupGradients code)
        let colors1 = [UIColor.blobBlue.cgColor, UIColor.clear.cgColor]
        let colors2 = [UIColor.blobPurple.cgColor, UIColor.clear.cgColor]
        
        blob1.type = .radial
        blob1.colors = colors1
        blob1.startPoint = CGPoint(x: 0.5, y: 0.5)
        blob1.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(blob1)
        
        blob2.type = .radial
        blob2.colors = colors2
        blob2.startPoint = CGPoint(x: 0.5, y: 0.5)
        blob2.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(blob2)
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
        
        // This guard is important: it prevents adding duplicate animations
        // if layoutSubviews is called while animations are already running.
        guard blob1.animation(forKey: "antiClockwise") == nil else { return }

        let w = bounds.width
        let h = bounds.height
        
        let topLeft     = CGPoint(x: 0, y: 0)
        let bottomLeft  = CGPoint(x: 0, y: h)
        let bottomRight = CGPoint(x: w, y: h)
        let topRight    = CGPoint(x: w, y: 0)
        
        let path1 = [topLeft, bottomLeft, bottomRight, topRight, topLeft]
        animateEdgeToEdge(layer: blob1, points: path1, duration: 30)
        
        let path2 = [bottomRight, topRight, topLeft, bottomLeft, bottomRight]
        animateEdgeToEdge(layer: blob2, points: path2, duration: 25)
    }

    private func animateEdgeToEdge(layer: CALayer, points: [CGPoint], duration: CFTimeInterval) {
        let anim = CAKeyframeAnimation(keyPath: "position")
        anim.values = points.map { NSValue(cgPoint: $0) }
        anim.duration = duration
        anim.repeatCount = .infinity
        
        // 3. Prevent the animation from being automatically removed
        anim.isRemovedOnCompletion = false
        
        anim.calculationMode = .paced
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        layer.add(anim, forKey: "antiClockwise")
    }
    
    // 4. Clean up the observer
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
