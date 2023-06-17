import AVFoundation

final class PhotoCaptureDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let didOutput: (CMSampleBuffer, AVCaptureConnection) -> Void
    
    init(didOutput: @escaping (CMSampleBuffer, AVCaptureConnection) -> Void) {
        self.didOutput = didOutput
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        didOutput(sampleBuffer, connection)
    }
    
}
