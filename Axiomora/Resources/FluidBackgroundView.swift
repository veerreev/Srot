import UIKit

class FluidBackgroundView: UIView {
    
    private let blob1 = CAGradientLayer()
    private let blob2 = CAGradientLayer()
    
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
        let colors1 = [Theme.Colors.blobBlue.cgColor, Theme.Colors.clear.cgColor]
        let colors2 = [Theme.Colors.blobPurple.cgColor, Theme.Colors.clear.cgColor]
        
        blob1.type = .radial
        blob1.colors = colors1
        blob1.startPoint = CGPoint(x: 0.5, y: 0.5)
        blob1.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(blob1, at: 0)
        
        blob2.type = .radial
        blob2.colors = colors2
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
