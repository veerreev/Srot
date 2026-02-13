//
//  LogInViewController.swift
//  Axiomora
//
//  Created by GEU on 12/02/26.
//

import UIKit

class LogInViewController: UIViewController {

    
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    @IBOutlet var logInButton: UIButton!
    @IBOutlet var footerLabel: UILabel!
    @IBOutlet var signUpButton: UIButton!
    
    // MARK: - Lock In Portrait
    
    override var shouldAutorotate: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Listen for keyboard events
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        setupUI()
        setupDismissKeyboardGesture()
        
        // Set the delegates
        usernameTextField.delegate = self
        passwordTextField.delegate = self
    }
    
    @IBAction func logInTapped(_ sender: Any) {
        
        guard let username = usernameTextField.text, !username.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            handleValidationError()
            return
        }
        
        // Proceed with signup logic (Firebase/AuthManager)
//        errorLabel.text = ""
        
        // Disable button to prevent multiple taps during "network" call
        logInButton.isEnabled = false
        
        AuthManager.shared.pseudoLogin(username: username, password: password ) { [weak self] success in
            guard let self = self else { return }
            
            // Re-enable button on the main thread
            self.logInButton.isEnabled = true
            
            if success {
                print("Log In Successful!")
                // Proceed to the next screen (e.g., Home screen)
            } else {
                print("Log In Failed.")
                // Show an error alert to the user
            }
        }
        
    }
    
    private func handleValidationError() {
        
        // Trigger Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        // Visual Shake Animation
        logInButton.shake()
        
        if usernameTextField.text?.isEmpty == true {
            usernameTextField.placeholderColor = .translucentRed
        }
        if passwordTextField.text?.isEmpty == true {
            passwordTextField.placeholderColor = .translucentRed
        }
    }
    
    @IBAction func signUpTapped(_ sender: Any) {
        let signUpStoryboard = UIStoryboard(name: "SignUpStoryboard", bundle: nil)
        
        guard let signUpVC = signUpStoryboard.instantiateInitialViewController() else {
            print ("Sign Up storyboard has no intial view controller")
            return
        }
        
        signUpVC.modalPresentationStyle = .fullScreen
        signUpVC.modalTransitionStyle = .crossDissolve
        present(signUpVC, animated: true, completion: nil)
    }
    
    private func setupUI() {
        
        var config = UIButton.Configuration.glass()
        
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        config.title = "Log In"
        config.baseForegroundColor = .white
        
        logInButton.backgroundColor = .systemBlue
        logInButton.configuration = config
        
        // Container Glass Effect
        // Note: Ensure containerView is a UIVisualEffectView in Storyboard
//        containerView.effect = UIGlassEffect()
//        containerView.layer.cornerRadius = 16
//        containerView.clipsToBounds = true
    }
    
    private func setupDismissKeyboardGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            // This ensures the tap doesn't interfere with button touches
//            tap.cancelsTouchesInView = false
            view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        // This forces the view (and any subview text fields) to stop editing
        view.endEditing(true)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            // Only shift if the view isn't already shifted
            if self.view.frame.origin.y == 0 {
                // We shift by about half the keyboard height to keep the fields centered in the remaining space
                self.view.frame.origin.y -= (keyboardSize.height / 2)
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        // Reset the view to its original position
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension LogInViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameTextField {
            // Move focus from Username -> Password
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            // Password finished -> Trigger Log In
            textField.resignFirstResponder()
            logInTapped(logInButton as Any)
        }
        return true
    }
}
