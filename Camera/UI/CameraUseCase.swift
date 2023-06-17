import AVFoundation
import Combine
import UIKit
import MetalKit

/// @abstract
/// Bare bones Reducer inspired by https://github.com/pointfreeco/swift-composable-architecture
///
/// @discussion
/// Manages CameraViewController's State and changes it on incoming actions.
/// Used to connect ViewController to all external services.
@MainActor
final class CameraUseCase {
    
    let session: AVCaptureSession
    
    let metalSessionClient: MetalSessionClient?
    
    // Private
    
    private let sessionClient: CaptureSessionClient
    private var sampleBufferDelegate: PhotoCaptureDelegate?
    
    // MARK: - Init
    
    init(state: State,
         sessionClient: CaptureSessionClient,
         metalSessionClient: MetalSessionClient?) {
        self.state = state
        self.sessionClient = sessionClient
        self.session = sessionClient.session()
        self.metalSessionClient = metalSessionClient
    }
    
    // MARK: - State
    
    struct State {
        var isAuthorized: Bool = false
        var isConfigured: Bool = false
        var isTakingPicture: Bool = false
        var isChangingCamera: Bool = false

        var capturedImage: UIImage? = nil
        var dimensions: CMVideoDimensions?
    }
    
    @Published private(set) var state: State
    
    // MARK: - Actions
    
    enum Action {
        // Actions
        case viewDidLoad
        case viewWillAppear
        case takePictureTapped
        case switchCameraTapped
        case configureMetalView(MTKView)
        
        // Effects
        case requestAccessResponse(Bool)
        case sessionConfigured(CaptureSessionConfiguration)
        case sessionConfiguredWithError(Error)
        case didTakePicture(UIImage)
        case changeCameraResponse(Error?)
    }
    
    func send(_ action: Action) {
        var newState = state
        // batch all state updates into one rerender
        handle(action, state: &newState)
        self.state = newState
    }
    
    private func handle(_ action: Action, state: inout State) {
        switch action {
        case .viewDidLoad:
            switch sessionClient.videoAuthorizationStatus() {
            case .authorized:
                state.isAuthorized = true
                
            case .notDetermined:
                Task(priority: .userInitiated) {
                    let granted = await sessionClient.requestVideoAccess()
                    
                    await MainActor.run {
                        send(.requestAccessResponse(granted))
                    }
                }
            default:
                state.isAuthorized = false
            }
            
        case .viewWillAppear:
            if state.isAuthorized {
                configureAndStartSession()
            }
            
        case let .configureMetalView(mtkView):
            metalSessionClient?.configureMetalView(mtkView)
            
        case let .requestAccessResponse(granted):
            if granted {
                print("Granted!")
                configureAndStartSession()
            } else {
                // TODO: Make beautiful UI for Not Granted flow
                print("Not Granted :(")
            }
            
            state.isAuthorized = granted
            
        case let .sessionConfigured(config):
            state.isConfigured = true
            state.dimensions = config.currentDeviceInput?
                .device
                .activeFormat
                .formatDescription
                .dimensions
            
        case let .sessionConfiguredWithError(error):
            state.isConfigured = false
            print(error.localizedDescription)
            
        case .takePictureTapped:
            state.isTakingPicture = true
            
        case .switchCameraTapped:
            state.isChangingCamera = true
            
            Task(priority: .userInitiated) {
                do {
                    try await sessionClient.toggleCamera()
                    await MainActor.run {
                        self.send(.changeCameraResponse(nil))
                    }
                } catch {
                    await MainActor.run {
                        self.send(.changeCameraResponse(error))
                    }
                }
            }
            
        case let .didTakePicture(picture):
            state.capturedImage = picture
            state.isTakingPicture = false
            
        case .changeCameraResponse:
            state.isChangingCamera = false
            
        }
    }

}

extension CameraUseCase {
    
    // MARK: - Configure Session
    
    private func configureAndStartSession() {
        Task(priority: .userInitiated) {
            do {
                let config = try await sessionClient.configure()
                configureSampleBufferDelegate()
                session.startRunning()
                
                send(.sessionConfigured(config))
            } catch {
                send(.sessionConfiguredWithError(error))
            }
        }
    }
    
    private func configureSampleBufferDelegate() {
        // completion handler is called on background queue
        sampleBufferDelegate = PhotoCaptureDelegate { [weak self] buffer, connection in
            self?.handleIncomingFrame(sampleBuffer: buffer, connection: connection)
        }
        
        Task(priority: .userInitiated) {
            await sessionClient.setSampleBufferDelegate(sampleBufferDelegate)
        }
    }
    
}

extension CameraUseCase {
    
    // MARK: - Frame
    
    // TODO: Take filters from the UI
    private func applyFilters(to original: CIImage) -> CIImage {
        // Testing with the noir filter
        let noirFilter = CIFilter(name: "CIPhotoEffectNoir")!
        noirFilter.setValue(original, forKey: kCIInputImageKey)
        return noirFilter.outputImage!
    }
    
    // Called on background queue
    private func handleIncomingFrame(sampleBuffer: CMSampleBuffer, connection: AVCaptureConnection) {
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let originalCIImage = CIImage(cvImageBuffer: cvBuffer)
        
        let finalCIImage = applyFilters(to: originalCIImage)
        
        metalSessionClient?.draw(finalCIImage)
        
        // because this delegate is called on dispatch queue
        // and does not support Swift concurrency, we use DispatchQueue for consistency
        let isTakingPicture = DispatchQueue.main.sync { self.state.isTakingPicture }
        
        guard isTakingPicture
        else { return }
        
        let uiImage = UIImage(ciImage: finalCIImage)
        
        DispatchQueue.main.sync {
            self.send(.didTakePicture(uiImage))
        }
    }
    
}
