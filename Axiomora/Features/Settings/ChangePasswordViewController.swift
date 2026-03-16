import UIKit

class ChangePasswordViewController: UIViewController {

    @IBOutlet weak var oldPassword: UITextField!
    @IBOutlet weak var newPassword: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func changePasswordTapped(_ sender: UIButton) {

        guard let old = oldPassword.text,
              let new = newPassword.text,
              !old.isEmpty,
              !new.isEmpty else {

            let alert = UIAlertController(
                title: "Error",
                message: "Please enter both passwords.",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        print("Password updated")

        let alert = UIAlertController(
            title: "Success",
            message: "Password updated successfully.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
