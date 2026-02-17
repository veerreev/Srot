//
//  AuthViewController.swift
//  Axiomora
//
//  Created by GEU on 10/02/26.
//

import UIKit

class SignUpViewController: UIViewController {

//    @IBOutlet var containerView: UIVisualEffectView!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var signUpButton: UIButton!
    @IBOutlet var errorLabel: UILabel!
    @IBOutlet var confirmPasswordTextField: UITextField!
    @IBOutlet var footerLabel: UILabel!
    @IBOutlet var logInButton: UIButton!
        
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
        emailTextField.delegate = self
        passwordTextField.delegate = self
        confirmPasswordTextField.delegate = self
        
    }

    // MARK: - Actions
    @IBAction func signUpTapped(_ sender: Any) {
        
        guard let username = usernameTextField.text, !username.isEmpty,
              let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty,
        let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            handleValidationError()
            return
        }
        
        // Proceed with signup logic (Firebase/AuthManager)
//        errorLabel.text = ""
        
        // Disable button to prevent multiple taps during "network" call
        signUpButton.isEnabled = false
        
        AuthManager.shared.pseudoSignUp(username: username, password: password, email: email) { [weak self] success in
            guard let self = self else { return }
            
            // Re-enable button on the main thread
            self.signUpButton.isEnabled = true
            
            if success {
                print("Sign Up Successful!")
                // Proceed to the next screen (e.g., Home screen)
            } else {
                print("Sign Up Failed.")
                // Show an error alert to the user
            }
        }
            
    }
    
    private func handleValidationError() {
        
        // Trigger Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        // Visual Shake Animation
        signUpButton.shake()
        
        if usernameTextField.text!.isEmpty {
            usernameTextField.placeholderColor = .translucentRed
        }
        if emailTextField.text!.isEmpty {
            emailTextField.placeholderColor = .translucentRed
        }
        if passwordTextField.text!.isEmpty {
            passwordTextField.placeholderColor = .translucentRed
        }
        if confirmPasswordTextField.text!.isEmpty {
            confirmPasswordTextField.placeholderColor = .translucentRed
        }
    }

    @IBAction func logInTapped(_ sender: Any) {
        let loginStoryboard = UIStoryboard(name: "LogInStoryboard", bundle: nil)
        
        guard let loginVC = loginStoryboard.instantiateInitialViewController() else {
            print("Error: LogInStoryboard has no Initial View Controller set.")
            return
        }
        
        loginVC.modalPresentationStyle = .fullScreen
        loginVC.modalTransitionStyle = .coverVertical
        
        self.present(loginVC, animated: true, completion: nil)
    }
    
    private func setupUI() {
        
        var config = UIButton.Configuration.glass()
        
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        config.title = "Sign Up"
        config.baseForegroundColor = .white
        
        signUpButton.backgroundColor = .systemBlue
        signUpButton.configuration = config
//        
//        // Container Glass Effect
//        // Note: Ensure containerView is a UIVisualEffectView in Storyboard
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

extension SignUpViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameTextField {
            // Move focus from Username -> Email
            emailTextField.becomeFirstResponder()
        } else if textField == emailTextField {
            // Move focus from Email -> Password
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            // Move focus from Password -> ConfirmPassword
            confirmPasswordTextField.becomeFirstResponder()
        } else if textField == confirmPasswordTextField {
            // Password finished -> Trigger Sign Up
            textField.resignFirstResponder()
            signUpTapped(signUpButton as Any)
        }
        return true
    }
}
