import UIKit
import AVFoundation
import MetalKit

/// CameraViewController's view
final class CameraView: UIView {
    
    struct Props: Equatable {
        let aspectRatio: CGFloat
    }
    
    let capturedImageView = UIImageView()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    // MARK: - Views
    
    let mtkView = MTKView()
    
    let previewContainerView = UIView()
    
    // TODO: Capture Button
    
    // MARK: - Setup
    
    private func setup() {
        backgroundColor = .black
        
        previewContainerView.layer.cornerRadius = 20
        previewContainerView.clipsToBounds = true
        addSubview(previewContainerView)
        previewContainerView.addSubview(mtkView)
        
        capturedImageView.backgroundColor = .white
        capturedImageView.contentMode = .scaleAspectFit
        addSubview(capturedImageView)
        
        // hide for Metal variant
//        previewView.isHidden = true
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let aspectRatio = props?.aspectRatio ?? 16.0 / 9.0
        
        previewContainerView.frame = CGRect(
            origin: CGPoint(x: 0, y: safeAreaInsets.top),
            size: CGSize(width: bounds.width,
                         height: bounds.width * aspectRatio)
        )
        mtkView.frame = previewContainerView.bounds
    }
    
    // MARK: - Render
    
    private var props: Props?
    
    func render(_ props: Props) {
        self.props = props
        setNeedsLayout()
    }

}
