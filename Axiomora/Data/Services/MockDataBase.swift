//
//  MockDataBase.swift
//  Axiomora
//
//  Created by GEU on 09/02/26.
//

/*import Foundation

class MockDataBase {
    static let shared = MockDataBase()
    
    var registeredUsers: [String: User] = [:]
    
    private init() {}
}*/
class MockDataBase {

    static let shared = MockDataBase()
    private init() {}

    // ✅ FIXED
    var registeredUsers: [String: User] = [:]

    func getSignatures() -> [Signature] {
        return [
            Signature(
                id: "1",
                creatorID: "1",
                title: "SIGN_INSTA",
                displayName: "James Finn",
                copyrightText: nil,
                email: nil,
                website: nil,
                socialHandles: [
                    SocialHandle(platform: .instagram, userInput: "@finejames234")
                ],
                shouldIncludeLocation: false
            ),
            Signature(
                id: "2",
                creatorID: "1",
                title: "SIGN_FB",
                displayName: "James Finn",
                copyrightText: nil,
                email: nil,
                website: nil,
                socialHandles: [
                    SocialHandle(platform: .facebook, userInput: "@James234")
                ],
                shouldIncludeLocation: false
            )
        ]
    }
}
