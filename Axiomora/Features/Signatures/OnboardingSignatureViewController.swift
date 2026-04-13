//
//  OnboardingSignatureViewController.swift
//  Axiomora
//
//  Created by Veer on 13/04/26.
//

import UIKit

class OnboardingSignatureViewController: UIViewController {

    @IBOutlet weak var goToCameraButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        Theme.Button.applyGlassStyle(to: goToCameraButton, title: "Go to Camera", color: Theme.Colors.systemBlue)
    }

    @IBAction func goToCameraTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "CameraStoryboard", bundle: nil)
        
        guard let viewController = storyboard.instantiateInitialViewController() else {
            return
        }
        
        viewController.modalPresentationStyle = .fullScreen
        viewController.modalTransitionStyle = .crossDissolve
        present(viewController, animated: true)
    }
}
