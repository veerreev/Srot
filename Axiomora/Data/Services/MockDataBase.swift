//
//  MockDataBase.swift
//  Axiomora
//
//  Created by GEU on 09/02/26.
//

import Foundation

class MockDataBase {
    static let shared = MockDataBase()
    
    var registeredUsers: [String: UserModel] = [:]
    
    private init() {}
}
