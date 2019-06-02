import Vision
import UIKit
import AVFoundation
import PlaygroundSupport
import PreviewViewController

// Parameters
let threshold: Float = 0.3

// ViewControllers
class ViewController: PreviewViewController {
    let fpsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = #colorLiteral(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        label.text = "fps: -"
        return label
    }()
    let bboxLayer = CALayer()
    
    let model = try! compileModel(at: #fileLiteral(resourceName: "MobileNetV2_SSDLite.mlmodel"))
    lazy var request: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: self.model, completionHandler: self.processDetections)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.layer.addSublayer(self.bboxLayer)
        self.view.addSubview(self.fpsLabel)
        
        NSLayoutConstraint.activate([
            self.fpsLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
        ])
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.bboxLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
    }
    
    func detect(imageBuffer: CVImageBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)
        
        let start = DispatchTime.now()
        try! handler.perform([self.request])
        let fps = 1 / DispatchTime.now().durationSec(since: start)
        DispatchQueue.main.async {
            self.fpsLabel.text = "fps: \(fps)"
        }
    }
    
    func processDetections(for request: VNRequest, error: Error?) {
        DispatchQueue.global().async {
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            
            // Remove all bboxes
            self.bboxLayer.sublayers = nil
            
            request.results?
                .lazy
                .compactMap { $0 as? VNRecognizedObjectObservation }
                .filter { $0.labels[0].confidence >= threshold }
                .forEach {
                    print($0.labels[0])
                    
                    let imgSize = self.bboxLayer.bounds.size;
                    let bbox = VNImageRectForNormalizedRect($0.boundingBox, Int(imgSize.width), Int(imgSize.height))
                    let cls = $0.labels[0]
                    
                    // Render a bounding box
                    let shapeLayer = CALayer()
                    shapeLayer.borderColor = #colorLiteral(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
                    shapeLayer.borderWidth = 2
                    shapeLayer.bounds = bbox
                    shapeLayer.position = CGPoint(x: bbox.midX, y: bbox.midY)
                    
                    // Render a description
                    let textLayer = CATextLayer()
                    textLayer.string = "\(cls.identifier): \(cls.confidence)"
                    textLayer.font = UIFont.preferredFont(forTextStyle: .body)
                    textLayer.bounds = CGRect(x: 0, y: 0, width: bbox.width - 10, height: bbox.height - 10)
                    textLayer.position = CGPoint(x: bbox.midX, y: bbox.midY)
                    textLayer.foregroundColor = #colorLiteral(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
                    textLayer.contentsScale = 2.0 // Retina Display
                    textLayer.setAffineTransform(CGAffineTransform(scaleX: 1, y: -1))
                    
                    shapeLayer.addSublayer(textLayer)
                    self.bboxLayer.addSublayer(shapeLayer)
                }
            
            CATransaction.commit()
        }
    }
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        super.captureOutput(output, didOutput: sampleBuffer, from: connection)
        
        if let size = CMSampleBufferGetImageBuffer(sampleBuffer).map(CVImageBufferGetDisplaySize) {
            let scaleX = self.view.bounds.width / size.width
            let scaleY = self.view.bounds.height / size.height
            let scale = fmin(scaleX, scaleY)
            
            self.bboxLayer.setAffineTransform(CGAffineTransform(scaleX: scale, y: -scale))
            self.bboxLayer.bounds = CGRect(origin: .zero, size: size)
            self.bboxLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        }
        
        CATransaction.commit()
        
        CMSampleBufferGetImageBuffer(sampleBuffer).map(self.detect)
    }
}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
