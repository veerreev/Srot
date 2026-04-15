//
//  SignaturePreviewDelegate.swift
//  Axiomora
//
//  Created by Veer on 15/04/26.
//


import UIKit

// MARK: - Delegate

protocol SignaturePreviewDelegate: AnyObject {
    func signaturePreview(
        _ vc: SignaturePreviewViewController,
        didTapSignature signature: Signature
    )
}


class SignaturePreviewViewController: UIViewController {

    // Set by SingleImageViewViewController before presenting
    var signature: Signature?
    var signatureIndex: Int = 0
    weak var delegate: SignaturePreviewDelegate?

    private var cardCell: SignatureCell?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCard()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Rebuild the social icons stack now that bounds are resolved
        cardCell?.buildSocialStackIfNeeded()
    }

    private func setupCard() {
        view.backgroundColor = .clear

        guard let sig = signature,
              let cell = Bundle.main.loadNibNamed("SignatureCell", owner: nil, options: nil)?.first as? SignatureCell
        else { return }

        cell.configure(with: sig, index: signatureIndex)
        let glassEffect = UIGlassEffect()
        glassEffect.tintColor = Theme.Colors.selectedSignatureBackground
        cell.visualEffectViewBackground.effect = glassEffect
        cell.isUserInteractionEnabled = true
        cell.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cell)

        NSLayoutConstraint.activate([
            cell.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cell.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cell.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            cell.heightAnchor.constraint(equalToConstant: 690)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        cell.addGestureRecognizer(tap)
        cardCell = cell
    }

    @objc private func cardTapped() {
        guard let sig = signature else { return }
        delegate?.signaturePreview(self, didTapSignature: sig)
    }
}
