import UIKit
import AVFoundation
import Combine

/// Main ViewController of the app
final class CameraViewController: UIViewController {
    
    let useCase: CameraUseCase
    
    init(useCase: CameraUseCase) {
        self.useCase = useCase
        self.currentState = useCase.state
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Views
    
    private var cameraView: CameraView {
        view as! CameraView
    }
    
    override func loadView() {
        self.view = CameraView()
    }
    
    // MARK: - Life cycle
    
    private var stateCancallable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        addObservers()
        configureGestures()
        
        useCase.send(.configureMetalView(cameraView.mtkView))
        useCase.send(.viewDidLoad)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        useCase.send(.viewWillAppear)
    }
    
    // MARK: - Configure
    
    private func addObservers() {
        stateCancallable = useCase.$state
            .receive(on: DispatchQueue.main)
            .sink { newState in
                self.render(newState)
                self.currentState = newState
            }
    }
    
    private func configureGestures() {
        // Debug mode tap to take a picture, won't work right now
        cameraView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleTap(gr:)))
        )
        
        // Debug mode long press to toggle
        cameraView.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gr:)))
        )
    }
    
    // MARK: - Render
    
    private var currentState: CameraUseCase.State
    
    private func render(_ newState: CameraUseCase.State) {
        view.isUserInteractionEnabled = !newState.isChangingCamera
        
        if newState.capturedImage != currentState.capturedImage {
            cameraView.capturedImageView.image = newState.capturedImage
        }
        
        let dimensions = newState.dimensions ?? CMVideoDimensions(width: 1080, height: 1920)
        let maxDimension = max(dimensions.width, dimensions.height)
        let minDimension = min(dimensions.width, dimensions.height)
        
        cameraView.render(
            CameraView.Props(
                aspectRatio: CGFloat(maxDimension) / CGFloat(minDimension)
            )
        )
    }

}

extension CameraViewController {
    
    // MARK: - Actions
    
    @objc
    private func handleTap(gr: UITapGestureRecognizer) {
        guard gr.state == .recognized else { return }
        
        useCase.send(.takePictureTapped)
    }
    
    @objc
    private func handleLongPress(gr: UILongPressGestureRecognizer) {
        guard gr.state == .recognized else { return }
        
        useCase.send(.switchCameraTapped)
    }
    
}
