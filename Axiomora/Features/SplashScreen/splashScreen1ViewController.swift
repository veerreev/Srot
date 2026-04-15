import UIKit

// A simple struct to hold the data for each step
struct OnboardingStep {
    let title: String
    let subtitle: String
}

class splashScreen1ViewController: UIViewController {

    @IBOutlet weak var signitLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!

    // Define your 4 screens here
    private let steps: [OnboardingStep] = [
        OnboardingStep(title: "Own Every Image\nYou Capture", subtitle: "Add an invisible identity to your photos, ensuring provenance and protection across the web"),
        OnboardingStep(title: "Your Identity,\nEmbedded", subtitle: "Add your name, title and social links as a hidden signature that lives within the pixel data of your assets"),
        OnboardingStep(title: "Ownership.\nTrust.\nAuthenticity.", subtitle: "Your signature stays even after screenshots and sharing"),
        OnboardingStep(title: "Know Who\nCaptured It", subtitle: "Scan and verify the original creator instantly with our invisible watermark")
    ]
    
    private var currentIndex = 0
    
    private func setupUI(for button: UIButton){
        Theme.Button.applyGlassStyle(to: nextButton, title: "Next", color: Theme.Colors.systemBlue)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        pageControl.numberOfPages = steps.count
        updateUI(animated: false)
        setupUI(for: nextButton)
    }

    private func updateUI(animated: Bool) {
        let step = steps[currentIndex]
        
        if pageControl.currentPage != currentIndex{
            pageControl.currentPage = currentIndex
        }
        
        // If it's the last page, change the button text
        let isLastPage = currentIndex == steps.count - 1
        nextButton.setTitle(isLastPage ? "Get Started" : "Next", for: .normal)
        skipButton.isHidden = isLastPage // Hide skip on the last page
        
        if animated {
            // Smooth cross-dissolve animation for the text
            UIView.transition(with: titleLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
                self.titleLabel.text = step.title
            }, completion: nil)
            
            UIView.transition(with: subtitleLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
                self.subtitleLabel.text = step.subtitle
            }, completion: nil)
        } else {
            titleLabel.text = step.title
            subtitleLabel.text = step.subtitle
        }
    }

    @IBAction func swipeDetected(_ sender: UISwipeGestureRecognizer) {
        if sender.direction == .left {
            if currentIndex < steps.count - 1 {
                currentIndex += 1
                updateUI(animated: true)
            }
        } else if sender.direction == .right {
            if currentIndex > 0 {
                currentIndex -= 1
                updateUI(animated: true)
            }
        }
    }
    // MARK: - Actions
    @IBAction func nextTapped(_ sender: UIButton) {
        if currentIndex < steps.count - 1 {
            // Go to the next step
            currentIndex += 1
            updateUI(animated: true)
        } else {
            // We are on the last page! Finish onboarding.
            finishOnboarding()
        }
    }

    @IBAction func skipTapped(_ sender: UIButton) {
        finishOnboarding()
    }
    
    @IBAction func pageControlTapped(_ sender: UIPageControl) {
    currentIndex = sender.currentPage
        
        updateUI(animated: true)
    }
    
    func finishOnboarding() {
        // Save that the user has seen the onboarding
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        
        // Transition to the main app (Camera)
        let storyboard = UIStoryboard(name: "RegisterStoryboard", bundle: nil)
        if let mainVC = storyboard.instantiateInitialViewController() {
            mainVC.modalPresentationStyle = .fullScreen
            mainVC.modalTransitionStyle = .crossDissolve
            self.present(mainVC, animated: true)
        }
    }
}
