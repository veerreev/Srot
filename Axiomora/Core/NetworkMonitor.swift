//
//  NetworkMonitor.swift
//  Axiomora
//
//  Created by GEU on 29/04/26.
//


import Foundation
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    
    // Tracks the current network state
    private var status: NWPath.Status = .requiresConnection
    
    var isConnected: Bool {
        return status == .satisfied
    }
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.status = path.status
        }
        let queue = DispatchQueue(label: "NetworkMonitorQueue")
        monitor.start(queue: queue)
    }
}
