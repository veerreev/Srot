//
//  Theme.swift
//  Axiomora
//
//  Created by Veer Krishna Sharma on 11/02/26.
//

import UIKit

struct Theme {
    struct Colors{
        
        /// Blues
        static let systemBlue: UIColor = UIColor.systemBlue
        static let primaryBlue: UIColor = UIColor.primaryBlue
        static let secondaryBlue: UIColor = UIColor.secondaryBlue
        static let tertiaryBlue: UIColor = UIColor.tertiaryBlue
        static let blobBlue: UIColor = UIColor.blobBlue
        
        /// Reds
        static let secondaryRed: UIColor = UIColor.translucentRed
        
        /// Purples
        static let blobPurple: UIColor = UIColor.blobPurple
        
        /// Others
        static let textFieldBackground: UIColor = UIColor.textFieldBackground
        static let white: UIColor = .white
        static let clear: UIColor = .clear
        static let black: UIColor = .black
        
    }
    
    struct TextField {
        static let cornerRadius: CGFloat = 8.0
        static let borderWidth: CGFloat = 0.7 // To hide the default border color
        static let borderColor = UIColor.black
    }
    
    struct Button {
        static func applyGlassStyle(to button: UIButton, title: String?, color: UIColor = .clear) {
            
            var config = UIButton.Configuration.glass()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            if title != nil {
                config.title = title
            }
            config.baseForegroundColor = .white
            
            button.backgroundColor = color
            button.configuration = config
        }
        
        static func applyGlassStyle(to button: UIButton, image: UIImage?, color: UIColor = .clear) {
            
            var config = UIButton.Configuration.glass()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            if image != nil {
                config.image = image
            }
            config.baseForegroundColor = .white
            
            button.backgroundColor = color
            button.configuration = config
        }
        
    }
}

