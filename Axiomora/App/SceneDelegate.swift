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
        guard let windowscene = scene as? UIWindowScene else { return }
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        let window = UIWindow(windowScene: windowscene)
        window.overrideUserInterfaceStyle = UIUserInterfaceStyle.dark
        
        /*
         Determine the correct root view controller before the window appears.
         This runs on every launch — including after the app is killed from recents.
         AuthManager.shared.isLoggedIn reads from UserDefaults (disk), so it correctly reflects the persisted state regardless of whether the app was killed or not.
        */
        let rootVC: UIViewController
            
            if AuthManager.shared.isLoggedIn {
                // User has a saved session => skip auth screens and go directly to the main screen(camera interface).
                let mainStoryboard = UIStoryboard(name: "CameraStoryboard", bundle: nil)
                guard let mainVC = mainStoryboard.instantiateInitialViewController() else {
                    fatalError("CameraStoryboard has no Initial View Controller set.")
                // fatalError is intentional here, if this crashes, it means the Initial View Controller is not set in CameraStoryboard, which is a configuration mistake that must be fixed, not silently handled.
                }
                rootVC = mainVC
            } else {
                // No saved session => send user to registration.
                let authStoryboard = UIStoryboard(name: "RegisterStoryboard", bundle: nil)
                guard let registerVC = authStoryboard.instantiateInitialViewController() else {
                    fatalError("RegisterStoryboard has no Initial View Controller set.")
                }
                rootVC = registerVC
            }
        
        /*
         old hardcoded storyboard - issue with this is that it is redirecting to the registration page everytime the app is opened:
         
         // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
         let storyboard = UIStoryboard(name: "RegisterStoryboard", bundle: nil)
         // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
         let rootVC = storyboard.instantiateInitialViewController()
        */
        
        window.rootViewController = rootVC
        self.window = window
        window.makeKeyAndVisible( )
    }
    

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

