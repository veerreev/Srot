//
//  SignaturesViewController.swift
//  Axiomora
//
//  Created by Veer on 26/03/26.
//

import UIKit

class SignaturesViewController: UIViewController {

    @IBOutlet weak var createNewSignatureButton: UIButton!
    @IBOutlet weak var addBarButtonItem: UIBarButtonItem!
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func addButtonTapped(_ sender: Any) {
        let source = addBarButtonItem.value(forKey: "view") as? UIView
        launchNewSignatureViewController(sourceView: source)
    }
    
    @IBAction func createNewSignatureTapped(_ sender: UIButton) {
        launchNewSignatureViewController(sourceView: sender)
    }
    
    private func launchNewSignatureViewController(sourceView: UIView?) {
        let storyboard = UIStoryboard(name: "NewSignatureStoryboard", bundle: nil)
        let navController = storyboard.instantiateInitialViewController() as! UINavigationController
        
        navController.preferredTransition = .zoom(options: .init()) { context in
            sourceView
        }
        
        present(navController, animated: true)
    }
}
