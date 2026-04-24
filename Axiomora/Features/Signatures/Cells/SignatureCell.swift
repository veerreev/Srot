//
//  SignatureCell.swift
//  Axiomora
//
//  Created by Veer on 02/04/26.
//

import UIKit

class SignatureCell: UICollectionViewCell {

    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var visualEffectViewBackground: UIVisualEffectView!

    @IBOutlet weak var nameEntryLabel: UILabel!

    @IBOutlet weak var emailEntryLabel: UILabel!

    @IBOutlet weak var portfolioEntryLabel: UILabel!
    @IBOutlet weak var portfolioCopyrightSeparator: UIView!

    @IBOutlet weak var locationIcon: UIImageView!
    @IBOutlet weak var locationLabel: UILabel!
    
    @IBOutlet weak var addedSocialsLabel: UILabel!
    @IBOutlet weak var socialStack1: UIStackView!

    @IBOutlet weak var separatorView: UIView!
    @IBOutlet weak var copyrightEntryLabel: UILabel!

    // MARK: - Private state

    private var storedSocialHandles: [SocialHandle] = []
    private var lastBuiltWidth: CGFloat = 0

    private let iconSize: CGFloat = 30
    private let overflowLabelEstimatedWidth: CGFloat = 40

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        storedSocialHandles = []
        lastBuiltWidth = 0
        clearStackView(socialStack1)
    }

    /// `layoutSubviews` is called once Auto Layout has resolved the real
    /// frame of every subview, so `socialStack1.bounds.width` is accurate
    /// here — unlike `configure(with:)`, which fires before layout.
    override func layoutSubviews() {
        super.layoutSubviews()

        let currentWidth = socialStack1.bounds.width
        guard currentWidth > 0,
              !storedSocialHandles.isEmpty,
              abs(currentWidth - lastBuiltWidth) > 0.5 else { return }

        lastBuiltWidth = currentWidth
        rebuildSocialStack()
    }

    func buildSocialStackIfNeeded() {
        let currentWidth = socialStack1.bounds.width
        guard currentWidth > 0,
              !storedSocialHandles.isEmpty,
              abs(currentWidth - lastBuiltWidth) > 0.5 else { return }

        lastBuiltWidth = currentWidth
        rebuildSocialStack()
    }

    func configure(with signature: Signature, index: Int, capturedLocation: String? = nil) {

        numberLabel.text = "\(index+1)"
        nameEntryLabel.text = signature.displayName
        emailEntryLabel.text = signature.email
        portfolioEntryLabel.text = signature.website
        
        if signature.shouldIncludeLocation {
            locationIcon.image = UIImage(systemName: "location")
            locationLabel.text = capturedLocation ?? "Location included"
        } else {
            locationIcon.image = UIImage(systemName: "location.slash")
            locationLabel.text = "Location not included"
        }
        copyrightEntryLabel.text = "© " + (signature.copyrightText ?? "")

        addedSocialsLabel.isHidden = signature.socialHandles.isEmpty

        if signature.copyrightText == nil { copyrightEntryLabel.isHidden = true }

        // Store handles and force a layout pass so layoutSubviews() can
        // build the stack once the true bounds are known.
        storedSocialHandles = signature.socialHandles
        lastBuiltWidth = 0          // invalidate so layoutSubviews rebuilds
        setNeedsLayout()

        setAsCurrentSignature(signature.isCurrent)
    }

    // MARK: - Stack building

    /// Rebuilds socialStack1 from scratch based on the stack's current
    /// bounds width, showing as many icons as physically fit and appending
    /// a "+N" label for any that overflow.
    private func rebuildSocialStack() {
        clearStackView(socialStack1)

        let stackWidth   = socialStack1.bounds.width
        let spacing      = socialStack1.spacing   // honour whatever value is set in the XIB
        let totalHandles = storedSocialHandles.count

        // How many icons fit if we use the full width (no overflow label)?
        let maxFull = iconsFitting(in: stackWidth, spacing: spacing)

        let displayCount: Int
        let showOverflow: Bool

        if totalHandles <= maxFull {
            displayCount = totalHandles
            showOverflow = false
        } else {
            // Reserve room for the "+N" label and its leading gap.
            let widthForIcons = stackWidth - overflowLabelEstimatedWidth - spacing
            displayCount = max(0, iconsFitting(in: widthForIcons, spacing: spacing))
            showOverflow = true
        }

        // Add the visible icon views.
        for i in 0..<displayCount {
            let iconView = makeIconView(for: storedSocialHandles[i])
            socialStack1.addArrangedSubview(iconView)
        }

        // Add "+N" overflow label if needed.
        if showOverflow {
            let remaining = totalHandles - displayCount
            let label = UILabel()
            label.text = "+\(remaining)"
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = UIColor.white.withAlphaComponent(0.75)
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            socialStack1.addArrangedSubview(label)
        }

        // Flexible trailing spacer so icons stay left-aligned.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        socialStack1.addArrangedSubview(spacer)
    }

    /// Returns the maximum number of `iconSize`-wide views that fit inside
    /// `availableWidth` when separated by `spacing`.
    ///
    /// Formula:  N × iconSize + (N − 1) × spacing ≤ availableWidth
    ///           N × (iconSize + spacing) ≤ availableWidth + spacing
    ///           N ≤ (availableWidth + spacing) / (iconSize + spacing)
    private func iconsFitting(in availableWidth: CGFloat, spacing: CGFloat) -> Int {
        guard availableWidth > 0 else { return 0 }
        return Int((availableWidth + spacing) / (iconSize + spacing))
    }

    // MARK: - Helpers

    private func makeIconView(for handle: SocialHandle) -> UIImageView {
        let imageView = UIImageView(image: UIImage(named: handle.platform.iconName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: iconSize),
            imageView.heightAnchor.constraint(equalToConstant: iconSize)
        ])
        imageView.layer.cornerRadius = iconSize / 2
        return imageView
    }

    private func clearStackView(_ stackView: UIStackView?) {
        guard let stackView else { return }
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    // MARK: - UI setup

    private func setupUI() {
        let glassEffect = UIGlassEffect()
        glassEffect.tintColor = Theme.Colors.signatureBackground
        visualEffectViewBackground.effect = glassEffect
        visualEffectViewBackground.layer.cornerRadius = 36
        glassEffect.tintColor = .primaryPurple

    }

    func setAsCurrentSignature(_ isCurrent: Bool) {
        let glassEffect = UIGlassEffect()
        glassEffect.tintColor = isCurrent ? Theme.Colors.selectedSignatureBackground : .clear
        UIView.animate(withDuration: 0.5,
                       delay: 0,
                       options: [.curveEaseInOut, .allowUserInteraction]) {
            self.visualEffectViewBackground.effect = glassEffect
        }
    }
}
