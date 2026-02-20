import Foundation
import Combine
import SwiftPhoenixClient

/// Connection state for the Phoenix WebSocket
enum ChannelConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

/// Service for managing Phoenix Channel connection for real-time analytics updates
@MainActor
final class AnalyticsChannelService: ObservableObject {
    static let shared = AnalyticsChannelService()
    
    // MARK: - Published Properties
    @Published private(set) var connectionState: ChannelConnectionState = .disconnected
    @Published private(set) var lastEventAt: Date?
    
    // MARK: - Event Publisher
    private let eventSubject = PassthroughSubject<AnalyticsEvent, Never>()
    var eventPublisher: AnyPublisher<AnalyticsEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private var socket: Socket?
    private var channel: Channel?
    private var reconnectTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Connect to the Phoenix WebSocket and join the analytics channel
    func connect() {
        guard connectionState == .disconnected else { return }
        
        connectionState = .connecting
        
        let socketURL = AppConfig.websocketURL
        socket = Socket(socketURL)
        
        socket?.onOpen { [weak self] in
            Task { @MainActor in
                self?.connectionState = .connected
                self?.joinChannel()
            }
        }
        
        socket?.onClose { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                if self.connectionState != .disconnected {
                    self.connectionState = .reconnecting
                    self.scheduleReconnect()
                }
            }
        }
        
        socket?.onError { [weak self] error in
            Task { @MainActor in
                print("[AnalyticsChannel] Socket error: \(error)")
                guard let self = self else { return }
                if self.connectionState != .disconnected {
                    self.connectionState = .reconnecting
                    self.scheduleReconnect()
                }
            }
        }
        
        socket?.connect()
    }
    
    /// Disconnect from the Phoenix WebSocket
    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        
        channel?.leave()
        channel = nil
        
        socket?.disconnect()
        socket = nil
        
        connectionState = .disconnected
    }
    
    // MARK: - Private Methods
    
    private func joinChannel() {
        guard let socket = socket else { return }
        
        channel = socket.channel("analytics:events")
        
        // Handle incoming analytics events
        channel?.on("analytics_event") { [weak self] message in
            Task { @MainActor in
                guard let self = self else { return }
                self.lastEventAt = Date()
                
                if let payload = message.payload as? [String: Any] {
                    let event = AnalyticsEvent(payload: payload)
                    self.eventSubject.send(event)
                }
            }
        }
        
        // Handle new_event (alternative event name)
        channel?.on("new_event") { [weak self] message in
            Task { @MainActor in
                guard let self = self else { return }
                self.lastEventAt = Date()
                
                if let payload = message.payload as? [String: Any] {
                    let event = AnalyticsEvent(payload: payload)
                    self.eventSubject.send(event)
                }
            }
        }
        
        channel?.join()
            .receive("ok") { [weak self] _ in
                Task { @MainActor in
                    print("[AnalyticsChannel] Joined channel successfully")
                    self?.connectionState = .connected
                }
            }
            .receive("error") { [weak self] response in
                Task { @MainActor in
                    print("[AnalyticsChannel] Failed to join channel: \(response.payload)")
                    self?.connectionState = .reconnecting
                    self?.scheduleReconnect()
                }
            }
    }
    
    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.socket?.disconnect()
                self?.socket = nil
                self?.channel = nil
                self?.connectionState = .disconnected
                self?.connect()
            }
        }
    }
}

// MARK: - Analytics Event Model
struct AnalyticsEvent: Identifiable {
    let id = UUID()
    let type: String
    let timestamp: Date
    let payload: [String: Any]
    
    init(payload: [String: Any]) {
        self.type = payload["type"] as? String ?? "unknown"
        if let ts = payload["timestamp"] as? TimeInterval {
            self.timestamp = Date(timeIntervalSince1970: ts)
        } else {
            self.timestamp = Date()
        }
        self.payload = payload
    }
}
