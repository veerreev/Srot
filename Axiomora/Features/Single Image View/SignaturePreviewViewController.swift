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
    var image: Image?
    weak var delegate: SignaturePreviewDelegate?

    /// Set to false to suppress the tap-to-navigate gesture on the signature card.
    var isCardTappable: Bool = true

    /// Set to true to hide the signature number label on the card (e.g. in the Verify flow).
    var hidesSignatureNumber: Bool = false

    /// Overridable strings for the empty-state message shown when `signature` is nil.
    var emptyTitle: String = "Signature Deleted"
    var emptyBody: String  = "The signature embedded in this image has been deleted and is no longer available."

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

        guard let sig = signature else {
            showDeletedSignatureMessage()
            return
        }

        guard let cell = Bundle.main.loadNibNamed("SignatureCell", owner: nil, options: nil)?.first as? SignatureCell
        else { return }

        cell.configure(with: sig, index: signatureIndex, capturedLocation: image?.capturedLocation)
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

        if isCardTappable {
            let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
            cell.addGestureRecognizer(tap)
        } else {
            cell.setNavigationElementsVisible(false)
        }

        if hidesSignatureNumber {
            cell.numberLabel.isHidden = true
        }
        cardCell = cell
    }

    @objc private func cardTapped() {
        guard let sig = signature else { return }
        delegate?.signaturePreview(self, didTapSignature: sig)
    }

    private func showDeletedSignatureMessage() {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .thin)
        let iconView = UIImageView(image: UIImage(systemName: "signature", withConfiguration: symbolConfig))
        iconView.tintColor = .tertiaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = emptyTitle
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = UILabel()
        bodyLabel.text = emptyBody
        bodyLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        bodyLabel.textColor = .tertiaryLabel
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.heightAnchor.constraint(equalToConstant: 48),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36)
        ])
    }
}
