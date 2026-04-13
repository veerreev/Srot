//
//  LogInViewController.swift
//  Axiomora
//
//  Created by GEU on 12/02/26.
//

import UIKit

class LogInViewController: BaseAuthViewController {

    
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    @IBOutlet var logInButton: UIButton!
    @IBOutlet var footerLabel: UILabel!
    @IBOutlet var registerButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI(for: logInButton)
        
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
        
        // Proceed with register logic (Firebase/AuthManager)
//        errorLabel.text = ""
        
        // Disable button to prevent multiple taps during "network" call
        logInButton.isEnabled = false
        
        AuthManager.shared.pseudoLogin(username: username, password: password ) { [weak self] success in
            guard let self = self else { return }
            
            // Re-enable button on the main thread
            self.logInButton.isEnabled = true
            
            if success {
                
                launchCameraStoryboard()
                
            } else {
                print("Log In Failed.")
                #warning("Show an error alert to the user")
            }
        }
        
    }
    
    private func handleValidationError() {
        
        // Use the base class method for error feedback!
        triggerErrorFeedback(on: logInButton)
        
        if usernameTextField.text?.isEmpty == true {
            usernameTextField.placeholderColor = Theme.Colors.secondaryRed
        }
        if passwordTextField.text?.isEmpty == true {
            passwordTextField.placeholderColor = Theme.Colors.secondaryRed
        }
    }
    
    @IBAction func registerTapped(_ sender: Any) {
        let registerStoryboard = UIStoryboard(name: "RegisterStoryboard", bundle: nil)
        
        guard let registerVC = registerStoryboard.instantiateInitialViewController() else {
            print ("Register storyboard has no intial view controller")
            return
        }
        
        registerVC.modalPresentationStyle = .fullScreen
        registerVC.modalTransitionStyle = .crossDissolve
        present(registerVC, animated: true, completion: nil)
    }
    
    private func setupUI(for button: UIButton) {
        
        Theme.Button.applyGlassStyle(to: logInButton, title: "Log In", color: Theme.Colors.systemBlue)
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
