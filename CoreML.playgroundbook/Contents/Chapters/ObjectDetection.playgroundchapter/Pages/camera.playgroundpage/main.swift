import Vision
import UIKit
import AVFoundation
import PlaygroundSupport

// Parameters
let threshold: Float = 0.3

// ViewControllers
class ViewController: UIViewController {
    let previewLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        return layer
    }()
    lazy var previewView: UIView = {
        let view = UIView()
        view.layer.addSublayer(self.previewLayer)
        return view
    }()
    lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["portrait", "portraitUpsideDown", "landscapeRight", "landscapeLeft"])
        control.selectedSegmentIndex = 3
        control.addTarget(self, action: "rotateCamera:", for: .valueChanged)
        return control
    }()
    lazy var cap = try! VideoCaptureDevice(preset: .photo)
    let model = try! compileModel(at: #fileLiteral(resourceName: "ObjectDetector.mlmodel"))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.titleView = self.segmentedControl
        self.view = self.previewView
        
        self.cap.delegate = self
        self.cap.start()
    }
    
    override func viewWillLayoutSubviews() {
        self.previewLayer.frame = self.view.bounds
    }
    
    @objc func rotateCamera(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            self.cap.rotate(orientation: .portrait)
        case 1:
            self.cap.rotate(orientation: .portraitUpsideDown)
        case 2:
            self.cap.rotate(orientation: .landscapeRight)
        case 3:
            self.cap.rotate(orientation: .landscapeLeft)
        default:
            break
        }
    }
    
    func detect(imageBuffer: CVImageBuffer) {
        let start = DispatchTime.now()
        
        // Object Detection
        let request = VNCoreMLRequest(model: self.model) { request, error in
            let end = DispatchTime.now()
            let elapsedNano = end.uptimeNanoseconds - start.uptimeNanoseconds
            let elapsed = Float64(elapsedNano) / 1_000_000_000
            let fps = 1 / elapsed
            
            // Remove all layers but the preview layer
            self.view.layer.sublayers?.removeSubrange(1...)
            
            request.results?
                .lazy
                .compactMap { $0 as? VNRecognizedObjectObservation }
                .filter { $0.labels[0].confidence >= threshold }
                .forEach {
                    print($0.labels[0])
                    
                    let bbox = $0.boundingBox
                        .applying(CGAffineTransform(scaleX: self.view.bounds.width, y: self.view.bounds.height))
                    
                    let layer = CAShapeLayer()
                    layer.strokeColor = #colorLiteral(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
                    layer.fillColor = nil
                    layer.path = UIBezierPath(rect: bbox).cgPath
                    DispatchQueue.main.async {
                        self.view.layer.addSublayer(layer)
                    }
                }
        }
        
        try! VNImageRequestHandler(cvPixelBuffer: imageBuffer).perform([request])
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            self.previewLayer.enqueue(sampleBuffer)
        }
        CMSampleBufferGetImageBuffer(sampleBuffer).map(self.detect)
    }
}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = UINavigationController(rootViewController: ViewController())
