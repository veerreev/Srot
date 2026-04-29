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
        
//        errorLabel.isHidden = true
    }

    // MARK: - Actions

    @IBAction func registerTapped(_ sender: Any) {
        if let errorMessage = validateFields() {
            showError(errorMessage)
            handleValidationError()
            return
        }

        clearError()

        let username = usernameTextField.text!
        let email    = emailTextField.text!.trimmingCharacters(in: .whitespaces)
        let password = passwordTextField.text!

        registerButton.isEnabled = false
        clearError()

        AuthManager.shared.register(username: username, password: password, email: email) { [weak self] success, errorMessage in
            guard let self = self else { return }
            self.registerButton.isEnabled = true

            if success {
                UserDefaults.standard.set(true, forKey: "hasRegistered")
                OnboardingManager.shared.beginOnboarding()
                self.launchCameraStoryboard()
            } else {
                // Show the exact error (Offline, Taken, etc.)
                self.handleValidationError()
                self.showError(errorMessage ?? "An unknown error occurred.")
            }
        }
    }
    
    private func handleValidationError() {
        triggerErrorFeedback(on: registerButton)

        if usernameTextField.text!.isEmpty {
            usernameTextField.placeholderColor = Theme.Colors.secondaryRed
        }
        if emailTextField.text!.isEmpty {
            emailTextField.placeholderColor = Theme.Colors.secondaryRed
        }
        if passwordTextField.text!.isEmpty {
            passwordTextField.placeholderColor = Theme.Colors.secondaryRed
        }
        if confirmPasswordTextField.text!.isEmpty {
            confirmPasswordTextField.placeholderColor = Theme.Colors.secondaryRed
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
        Theme.Button.applyGlassStyle(to: registerButton, title: "Register", color: Theme.Colors.systemBlue)
    }
    
}

// MARK: - UITextFieldDelegate

extension RegisterViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameTextField {
            emailTextField.becomeFirstResponder()
        } else if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            confirmPasswordTextField.becomeFirstResponder()
        } else if textField == confirmPasswordTextField {
            textField.resignFirstResponder()
            registerTapped(registerButton as Any)
        }
        return true
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        clearError()
    }
}

// MARK: - Validation

extension RegisterViewController {
  
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: email)
    }
  
    /// Returns an error message string, or nil if all fields are valid.
    private func validateFields() -> String? {
        let username = usernameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let email    = emailTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let password = passwordTextField.text ?? ""
        let confirm  = confirmPasswordTextField.text ?? ""

        if username.isEmpty  { return "Please enter a username." }
        if email.isEmpty     { return "Please enter your email address." }
        if !isValidEmail(email) { return "Please enter a valid email address." }
        if password.isEmpty  { return "Please enter a password." }
        if confirm.isEmpty   { return "Please confirm your password." }
        if password != confirm { return "Passwords do not match." }

        return nil
    }
  
    private func showError(_ message: String) {
        errorLabel.text = message
    }
 
    private func clearError() {
        guard !errorLabel.isHidden else { return }
        errorLabel.text = ""
    }
}
