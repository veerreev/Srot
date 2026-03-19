//
//  AuthViewController.swift
//  Axiomora
//
//  Created by GEU on 10/02/26.
//

import UIKit

class RegisterViewController: BaseAuthViewController {

//    @IBOutlet var containerView: UIVisualEffectView!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var registerButton: UIButton!
    @IBOutlet var errorLabel: UILabel!
    @IBOutlet var confirmPasswordTextField: UITextField!
    @IBOutlet var footerLabel: UILabel!
    @IBOutlet var logInButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI(for: registerButton)
        
        // Set the delegates
        usernameTextField.delegate = self
        emailTextField.delegate = self
        passwordTextField.delegate = self
        confirmPasswordTextField.delegate = self
        
    }

    // MARK: - Actions
    @IBAction func registerTapped(_ sender: Any) {
        
        guard let username = usernameTextField.text, !username.isEmpty,
              let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty,
        let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            handleValidationError()
            return
        }
        
        // Proceed with register logic (Firebase/AuthManager)
        // errorLabel.text = ""
        
        // Disable button to prevent multiple taps during "network" call
        registerButton.isEnabled = false
        
        AuthManager.shared.pseudoRegister(username: username, password: password, email: email) { [weak self] success in
            guard let self = self else { return }
            
            // Re-enable button on the main thread
            self.registerButton.isEnabled = true
            
            if success {
                
                launchCameraStoryboard()
                
            } else {
                print("Registration Failed.")
                #warning("Show an error alert to the user")
            }
        }
            
    }
    
    private func handleValidationError() {
        
        // Use the base class method for error feedback!
        triggerErrorFeedback(on: registerButton)
        
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
        loginVC.modalTransitionStyle = .crossDissolve
        
        self.present(loginVC, animated: true, completion: nil)
    }
    
    private func setupUI(for button: UIButton) {
        
        Theme.Button.applyGlassStyle(to: registerButton, title: "Register", color: .primaryBlue)
    }
    
}

extension RegisterViewController: UITextFieldDelegate {
    
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
            // Password finished -> Trigger Register
            textField.resignFirstResponder()
            registerTapped(registerButton as Any)
        }
        return true
    }
}
