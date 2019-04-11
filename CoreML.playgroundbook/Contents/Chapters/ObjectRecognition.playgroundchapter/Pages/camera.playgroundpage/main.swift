import Vision
import UIKit
import AVFoundation
import PlaygroundSupport

// Parameters
let threshold: Float = 0.5

// ViewControllers
class ViewController: UIViewController {
    let previewLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        return layer
    }()
    let fpsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = #colorLiteral(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        label.text = "fps: -"
        return label
    }()
    lazy var previewView: UIView = {
        let view = UIView()
        
        view.layer.addSublayer(self.previewLayer)
        
        view.addSubview(self.fpsLabel)
        NSLayoutConstraint.activate([
            self.fpsLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        return view
    }()
    let classesLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 1.0)
        label.text = "Nothing is detected."
        return label
    }()
    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [self.previewView, self.classesLabel])
        stackView.axis = .vertical
        return stackView
    }()
    lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["portrait", "portraitUpsideDown", "landscapeRight", "landscapeLeft"])
        control.selectedSegmentIndex = 3
        control.addTarget(self, action: "rotateCamera:", for: .valueChanged)
        return control
    }()
    lazy var cap = try! VideoCaptureDevice(preset: .photo)
    let model = try! compileModel(at: #fileLiteral(resourceName: "MobileNet.mlmodel"))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.titleView = self.segmentedControl
        self.view = self.stackView
        
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
        
        // Object Recognition
        let request = VNCoreMLRequest(model: self.model) { request, error in
            let end = DispatchTime.now()
            let elapsedNano = end.uptimeNanoseconds - start.uptimeNanoseconds
            let elapsed = Float64(elapsedNano) / 1_000_000_000
            let fps = 1 / elapsed
            
            DispatchQueue.main.async {
                self.fpsLabel.text = "fps: \(fps)"
                
                self.classesLabel.text = ""
            }
            
            request.results?
                .lazy
                .compactMap { $0 as? VNClassificationObservation }
                .filter { $0.confidence >= threshold }
                .forEach { cls in
                    DispatchQueue.main.async {
                        self.classesLabel.text?.append("\(cls.identifier): \(cls.confidence)\n")
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
