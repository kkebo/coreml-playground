import Vision
import UIKit
import AVFoundation
import PlaygroundSupport

// Parameters
let threshold: Float = 0.3

// ViewControllers
class ViewController: UIViewController {
    let previewLayer = AVSampleBufferDisplayLayer()
    let fpsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = #colorLiteral(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        label.text = "fps: -"
        return label
    }()
    let bboxLayer = CALayer()
    lazy var previewView: UIView = {
        let view = UIView()
        
        view.layer.addSublayer(self.previewLayer)
        view.layer.addSublayer(self.bboxLayer)
        
        view.addSubview(self.fpsLabel)
        view.addSubview(self.segmentedControl)
        
        return view
    }()
    lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["portrait", "portraitUpsideDown", "landscapeRight", "landscapeLeft"])
        control.selectedSegmentIndex = 3
        control.addTarget(self, action: "rotateCamera:", for: .valueChanged)
        
        control.translatesAutoresizingMaskIntoConstraints = false
        control.backgroundColor = .clear
        control.tintColor = .clear
        control.setTitleTextAttributes(
            [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline),
                NSAttributedString.Key.foregroundColor: UIColor.lightGray
            ],
            for: .normal
        )
        control.setTitleTextAttributes(
            [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline),
                NSAttributedString.Key.foregroundColor: UIColor.orange
            ],
            for: .selected
        )
        
        return control
    }()
    lazy var cap = try! VideoCaptureDevice(preset: .photo)
    let model = try! compileModel(at: #fileLiteral(resourceName: "MobileNetV2_SSDLite.mlmodel"))
    lazy var request: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: self.model, completionHandler: self.processDetections)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view = self.previewView
        
        NSLayoutConstraint.activate([
            self.fpsLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.segmentedControl.topAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.topAnchor),
            self.segmentedControl.centerXAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.centerXAnchor)
        ])
        
        self.cap.delegate = self
        self.cap.start()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.previewLayer.frame = self.view.bounds
        self.bboxLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
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
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.previewLayer.enqueue(sampleBuffer)
        
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

extension ViewController: PlaygroundLiveViewSafeAreaContainer {}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
