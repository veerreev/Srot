//
//  Theme.swift
//  Axiomora
//
//  Created by Veer Krishna Sharma on 11/02/26.
//

import UIKit

struct Theme {
    struct TextField {
        static let cornerRadius: CGFloat = 8.0
        static let borderWidth: CGFloat = 0.7 // To hide the default border color
        static let borderColor = UIColor.black
    }
    
    struct Button {
        static func applyPrimaryBlueStyle(to button: UIButton, title: String?) {
            
            var config = UIButton.Configuration.glass()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            if title != nil {
                config.title = title
            }
            config.baseForegroundColor = .white
            
            button.backgroundColor = .primaryBlue
            button.configuration = config
        }
        
        static func applyPrimaryBlueStyle(to button: UIButton) {
            
            var config = UIButton.Configuration.glass()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            config.baseForegroundColor = .white
            
            button.backgroundColor = .primaryBlue
            button.configuration = config
        }
        
    }
}
