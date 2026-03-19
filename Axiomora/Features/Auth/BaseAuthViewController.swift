//
//  BaseAuthViewController.swift
//  Axiomora
//
//  Created by Veer on 13/02/26.
//

import UIKit

class BaseAuthViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardObservers()
        setupDismissKeyboardGesture()
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func setupDismissKeyboardGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0 {
                self.view.frame.origin.y -= (keyboardSize.height / 2)
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }

    func triggerErrorFeedback(on button: UIButton) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        button.shake() // Uses UIView+Extension
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}

/*
 Transitions the app from any auth screen to the main camera screen after a successful registration or login.
 Replaces the window's rootViewController in memory instead of just stacking on top.
 This ensures the auth screens are fully removed from memory — the user cannot navigate back to registration after successfully logging in.
*/
extension BaseAuthViewController {
    
    func launchCameraStoryboard() {
        let cameraStoryboard = UIStoryboard(name: "CameraStoryboard", bundle: nil)
        
        guard let cameraVC = cameraStoryboard.instantiateInitialViewController() else {
            print("Error instantiating CameraViewController")
#warning("Error handling not done here")
            return
        }
        
        /*
         Traverse up from the current view to reach the SceneDelegate's window.
         The window is needed to swap rootViewController at the app level.
        */
        guard let windowScene = self.view.window?.windowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate else {
            print("Error: Could not access SceneDelegate.")
            return
        }
        
        UIView.transition(with: sceneDelegate.window!,
                          duration: 0.4,
                          options: .transitionCrossDissolve,
                          animations: {
            sceneDelegate.window?.rootViewController = cameraVC
        })
    }
}
