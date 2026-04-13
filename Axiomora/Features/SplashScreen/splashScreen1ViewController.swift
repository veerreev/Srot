//
//  splashScreen1ViewController.swift
//  Axiomora
//
//  Created by Dhruv Negi on 13/04/26.
//

import UIKit

class splashScreen1ViewController: UIViewController {

    @IBOutlet weak var signitLabel: UILabel!
        @IBOutlet weak var titleLabel: UILabel!
        @IBOutlet weak var subtitleLabel: UILabel!
        @IBOutlet weak var pageControl: UIPageControl!
        @IBOutlet weak var nextButton: UIButton!
        @IBOutlet weak var skipButton: UIButton!

        override func viewDidLoad() {
            super.viewDidLoad()

        }


        // MARK: - Actions
        @IBAction func nextTapped(_ sender: UIButton) {
            print("Start Planning tapped")
        }

        @IBAction func skipTapped(_ sender: UIButton) {
            print("Skip tapped")
        }
    }
