import CoreML
import Vision
import UIKit
import AVFoundation
import PlaygroundSupport

// ViewControllers
class ViewController: UIViewController {
    var request: VNCoreMLRequest!
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
    let label: UILabel = {
        let view = UILabel()
        view.textAlignment = .center
        view.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 1.0)
        view.text = "Nothing is detected."
        return view
    }()
    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [self.previewView, self.label])
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.titleView = self.segmentedControl
        self.view = self.stackView
        
        self.setupCoreML()
        
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
    
    func setupCoreML() {
        let modelUrl = #fileLiteral(resourceName: "MobileNet.mlmodel")
        let compiledUrl = try! MLModel.compileModel(at: modelUrl)
        let model = try! VNCoreMLModel(for: try! MLModel(contentsOf: compiledUrl))
        self.request = VNCoreMLRequest(model: model) { request, error in
            if let observations = request.results as? [VNClassificationObservation], let best = observations.first {
                DispatchQueue.main.async {
                    self.label.text = "\(best.identifier): \(best.confidence)"
                }
            }
        }
    }
    
    func detect(imageBuffer: CVImageBuffer) {
        // Object Recognition
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)
        let result = Result { try handler.perform([self.request]) }
        if case let .failure(error) = result {
            fatalError(error.localizedDescription)
        }
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

PlaygroundPage.current.liveView = UINavigationController(rootViewController: ViewController())
