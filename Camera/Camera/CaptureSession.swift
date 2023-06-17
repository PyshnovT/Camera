import AVFoundation

/// @abstract
/// A wrapper around private `CaptureSession` actor.
///
/// @discussion
/// Separate Client struct is necessary for switching between the live camera in production
/// and mock values in SwiftUI previews / Simulator. Useful for writing tests.
struct CaptureSessionClient {
    
    var videoAuthorizationStatus: @Sendable () -> AVAuthorizationStatus
    var requestVideoAccess: @Sendable () async -> Bool
    
    var configure: @Sendable () async throws -> CaptureSessionConfiguration
    var setSampleBufferDelegate: (AVCaptureVideoDataOutputSampleBufferDelegate?) async -> Void
    var startRunning: () async -> Void
    
    var session: () -> AVCaptureSession
    var toggleCamera: () async throws -> Void
    
    static var liveValue: Self {
        let captureSession = CaptureSession()
        
        return Self(
            videoAuthorizationStatus: { CaptureSession.videoAuthorizationStatus },
            requestVideoAccess: { await CaptureSession.requestVideoAccess() },
            configure: { try await captureSession.configureSession() },
            setSampleBufferDelegate: { delegate in
                await captureSession.setSampleBufferDelegate(delegate)
            },
            startRunning: { await captureSession.startRunning() },
            session: { captureSession.session },
            toggleCamera: { try await captureSession.toggleVideoInput() }
        )
    }
}

extension CaptureSessionClient {
    
    // Computed vars
    
    var isAuthorized: Bool {
        videoAuthorizationStatus() == .authorized
    }
    
}

/// @abstract
/// Result of the configuration of a camera
struct CaptureSessionConfiguration {
    let currentDeviceInput: AVCaptureDeviceInput?
}

/// @abstract
/// Actor that manages AVCaptureSession
///
/// @discussion
/// Made private to force developer to use CaptureSessionClient
private actor CaptureSession {
    
    nonisolated let session: AVCaptureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentDeviceInput: AVCaptureDeviceInput?
    private var captureDelegate: PhotoCaptureDelegate?
    
    private var isFrontCameraOn: Bool {
        currentDeviceInput?.device.position == .front
    }
    
    private var isBackCameraOn: Bool {
        currentDeviceInput?.device.position == .back
    }
    
}

extension CaptureSession {
    
    // MARK: - Configuration
    
    func configureSession() throws -> CaptureSessionConfiguration {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .photo
        }
        
        let input = try addVideoInput()
        try addVideoOutput()
        
        return CaptureSessionConfiguration(
            currentDeviceInput: input
        )
    }
    
    func setSampleBufferDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate?) {
        videoOutput.setSampleBufferDelegate(
            delegate,
            queue: DispatchQueue(label: "sampleBuffer.queue",
                                 qos: .userInitiated)
        )
    }
    
    // MARK: - Inputs & Outputs
    
    private func addVideoInput() throws -> AVCaptureDeviceInput {
        guard let videoDevice = getInitialCamera() else {
            print("Default video device is unavailable.")
            throw Error.deviceNotAvailable
        }
        
        let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        
        guard session.canAddInput(videoDeviceInput) else {
            print("Couldn't add video device input to the session.")
            throw Error.deviceNotAvailable
        }
        
        currentDeviceInput = videoDeviceInput
        session.addInput(videoDeviceInput)
        
        return videoDeviceInput
    }
    
    private func addVideoOutput() throws {
        guard session.canAddOutput(videoOutput) else {
            print("Could not add photo output to the session")
            throw Error.outputNotAvailable
        }
        
        session.addOutput(videoOutput)
        
        updateInputOutputConnection()
    }
    
    // Called on the initial setup and on every camera change
    // because connections get discarded
    private func updateInputOutputConnection() {
        // in this app we will always use portrait mode
        videoOutput.connections.forEach {
            $0.videoOrientation = .portrait
            $0.isVideoMirrored = isFrontCameraOn
        }
    }
    
    // MARK: Toggle
    
    private func toggleVideoDevice(_ currentDevice: AVCaptureDevice) -> AVCaptureDevice? {
        switch currentDevice.position {
        case .unspecified, .front:
            return getDefaultBackCamera()
            
        case .back:
            return getDefaultFrontCamera()
            
        @unknown default:
            print("Unknown capture position. Defaulting to back, dual-camera.")
            return getDefaultBackCamera() ?? .default(.builtInDualCamera, for: .video, position: .back)
        }
    }
    
    func toggleVideoInput() throws {
        guard let currentDeviceInput,
              let newDevice = toggleVideoDevice(currentDeviceInput.device)
        else { throw Error.deviceNotAvailable }
        
        let newInput = try AVCaptureDeviceInput(device: newDevice)
        
        session.beginConfiguration()
        session.removeInput(currentDeviceInput)
        
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            self.currentDeviceInput = newInput
        }
        
        updateInputOutputConnection()
        
        session.commitConfiguration()
    }
    
}

extension CaptureSession {
    
    // MARK: - State
    
    func startRunning() {
        session.startRunning()
    }
    
}

extension CaptureSession {
    
    // MARK: - Devices
    
    private var backVideoDeviceTypes: [AVCaptureDevice.DeviceType] {
        [.builtInTripleCamera,
         .builtInDualWideCamera,
         .builtInDualCamera,
         .builtInWideAngleCamera]
    }
    
    private var frontVideoDeviceTypes: [AVCaptureDevice.DeviceType] {
        [.builtInTrueDepthCamera,
         .builtInWideAngleCamera]
    }
    
    private func getDefaultBackCamera() -> AVCaptureDevice? {
        let backVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: backVideoDeviceTypes,
            mediaType: .video,
            position: .back
        )
        
        return backVideoDeviceDiscoverySession.devices.first
    }
    
    private func getDefaultFrontCamera() -> AVCaptureDevice? {
        let backVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: frontVideoDeviceTypes,
            mediaType: .video,
            position: .front
        )
        
        return backVideoDeviceDiscoverySession.devices.first
    }
    
    private func getInitialCamera() -> AVCaptureDevice? {
        getDefaultBackCamera() ?? getDefaultFrontCamera()
    }
    
}

extension CaptureSession {
    
    // MARK: - Permissions
    
    static var videoAuthorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    static func requestVideoAccess() async -> Bool {
        await withUnsafeContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
}

extension CaptureSession {
    
    // MARK: - Error
    
    enum Error: Swift.Error {
        case deviceNotAvailable
        case outputNotAvailable
    }
    
}
