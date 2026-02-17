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
        button.shake() // Uses your UIView+Extension
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}
