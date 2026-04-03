//
//  ChipView.swift
//  Axiomora
//
//  Created by Veer on 03/04/26.
//
import UIKit

@IBDesignable 
final class ChipView: UIView {

    private let iconView = UIImageView()
    private let handleLabel = UILabel()

    init(platform: SocialPlatform, handle: String) {
        super.init(frame: .zero)
        layer.cornerRadius = 12
        layer.masksToBounds = true
        backgroundColor = Theme.Colors.primaryBlue
        setupLayout(platform: platform, handle: handle)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    private func setupLayout(platform: SocialPlatform, handle: String) {
        iconView.image = UIImage(named: platform.iconName)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Theme.Colors.white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
        ])

        // Strip leading '@' for display — same logic your SocialHandle already does
        var displayHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayHandle.hasPrefix("@") { displayHandle.removeFirst() }
        handleLabel.text = displayHandle
        handleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        handleLabel.textColor = Theme.Colors.white

        let stack = UIStackView(arrangedSubviews: [iconView, handleLabel])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])
    }
}
