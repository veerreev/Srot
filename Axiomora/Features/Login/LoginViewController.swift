//
//  LoginViewController.swift
//  Axiomora
//
//  Created by GEU on 04/02/26.
//

import UIKit

class LoginViewController: UIViewController {

    
    @IBOutlet var containerView: UIVisualEffectView!
    
//    let glassEffectView = UIVisualEffectView()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupGlassContainer()
        // Do any additional setup after loading the view.
        
        // UIBackgroundExtensionView
        
    }
    
    private func setupGlassContainer() {
            // 1. Style the main container from the Storyboard
            containerView.layer.cornerRadius = 30 // 64 might be too aggressive for a login box
            containerView.clipsToBounds = true
            
            // 2. Apply the Glass Effect (iOS 17+)
            // Note: For older versions, use UIBlurEffect(style: .systemThinMaterial)
            containerView.effect = UIGlassEffect()
            
            // 3. Optional: Adding a border to enhance the 'glass' feel
//            containerView.layer.borderWidth = 0.5
//            containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            
            /* LOGIC FIX: If you MUST add glassEffectView programmatically,
            you have to give it a frame or constraints.
            */
            let glassEffectView = UIVisualEffectView(effect: UIGlassEffect())
            glassEffectView.frame = containerView.bounds // Match parent size
            glassEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight] // Keep it matched during rotation
            
            // containerView.contentView.addSubview(glassEffectView)
            // ^ Only uncomment if you actually need two layers of glass.
        }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
