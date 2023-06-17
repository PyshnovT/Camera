import MetalKit

/// @abstract
/// A wrapper around private `MetalSession` actor.
struct MetalSessionClient {
    var configureMetalView: (MTKView) -> Void
    var draw: (CIImage) -> Void
    
    /// Renders frames for MTKView using Core Image Context
    static var ciFiltersClient: Self? {
        guard let session = MetalSession()
        else { return nil }
        
        let frameQueue = DispatchQueue(label: "MetalSessionClient.queue", qos: .userInitiated)
        let ciContext = CIContext(mtlDevice: session.device)
        
        var currentFrame: CIImage?
        
        let ciFiltersDelegate = MetalViewDelegate(
            drawableSizeWillChange: { _, _ in },
            draw: { view in
                guard let commandBuffer = session.commandQueue.makeCommandBuffer(),
                      let currentFrame,
                      let currentDrawable = view.currentDrawable
                else { return }
                
                let frameSize = currentFrame.extent
                let drawableSize = view.drawableSize
                
                let scaleFactor = max(drawableSize.width / frameSize.width,
                                      drawableSize.height / frameSize.height)
                
                // upscale / downscale 1080x1920 image to device screen size
                let scaledCiImage = currentFrame
                    .transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
                
                ciContext.render(scaledCiImage,
                                 to: currentDrawable.texture,
                                 commandBuffer: commandBuffer,
                                 bounds: CGRect(origin: .zero, size: drawableSize),
                                 colorSpace: CGColorSpaceCreateDeviceRGB())
                
                commandBuffer.present(currentDrawable)
                
                commandBuffer.commit()
            }
        )
        
        return Self(
            configureMetalView: {
                session.configure($0, delegate: ciFiltersDelegate)
            },
            draw: { ciImage in
                frameQueue.sync {
                    currentFrame = ciImage
                }
                session.draw()
            }
        )
    }
    
}

/// @abstract
/// Handles Metal-rendering flow for partucular MTKView
private final class MetalSession {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    var mtkView: MTKView?
    
    init?(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        guard let device,
              let commandQueue = device.makeCommandQueue()
        else { return nil }
        
        self.device = device
        self.commandQueue = commandQueue
    }
    
}

extension MetalSession {
    
    func configure(_ mtkView: MTKView, delegate: MTKViewDelegate) {
        self.mtkView = mtkView
        
        mtkView.device = device
        mtkView.delegate = delegate
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = false
        
        // turn on writing to drawable object
        mtkView.framebufferOnly = false
    }
    
    func draw() {
        mtkView?.draw()
    }
    
}
