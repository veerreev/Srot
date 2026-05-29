//
//  SceneDelegate.swift
//  Axiomora
//
//  Created by GEU on 31/01/26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        let hasRegistered = UserDefaults.standard.bool(forKey: "hasRegistered")
        let hasLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        
        if (hasSeenOnboarding && hasRegistered) || (hasLoggedIn) {
            // Send them straight to the app
            let storyboard = UIStoryboard(name: "CameraStoryboard", bundle: nil)
            window.rootViewController = storyboard.instantiateInitialViewController()
        } else if hasSeenOnboarding {
            // Send them to registration
            let storyboard = UIStoryboard(name: "RegisterStoryboard", bundle: nil)
            window.rootViewController = storyboard.instantiateInitialViewController()
        } else {
            // Show the Splash Screens
            let storyboard = UIStoryboard(name: "splashScreen1", bundle: nil)
            window.rootViewController = storyboard.instantiateInitialViewController()
        }
        
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
}
