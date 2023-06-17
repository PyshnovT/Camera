import MetalKit

final class MetalViewDelegate: NSObject, MTKViewDelegate {
    
    let drawableSizeWillChange: (MTKView, CGSize) -> Void
    let draw: (MTKView) -> Void
    
    init(
        drawableSizeWillChange: @escaping (MTKView, CGSize) -> Void,
        draw: @escaping (MTKView) -> Void
    ) {
        self.drawableSizeWillChange = drawableSizeWillChange
        self.draw = draw
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSizeWillChange(view, size)
    }
    
    func draw(in view: MTKView) {
        draw(view)
    }
    
}
