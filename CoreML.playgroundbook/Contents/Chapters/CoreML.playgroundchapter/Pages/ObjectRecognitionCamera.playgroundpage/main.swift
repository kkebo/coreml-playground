import Vision
import UIKit
import AVFoundation
import PlaygroundSupport
import PreviewViewController

// Parameters
let threshold: Float = 0.5

// ViewControllers
class ViewController: PreviewViewController {
    let fpsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = #colorLiteral(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        label.text = "fps: -"
        return label
    }()
    let classesLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 0.5)
        label.text = "Nothing is detected."
        return label
    }()
    
    let model = try! compileModel(at: #fileLiteral(resourceName: "MobileNet.mlmodel"))
    lazy var request: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: self.model, completionHandler: self.processClassifications)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.classesLabel)
        self.view.addSubview(self.fpsLabel)
        
        NSLayoutConstraint.activate([
            self.classesLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.classesLabel.leadingAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.leadingAnchor),
            self.classesLabel.trailingAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.trailingAnchor),
            self.fpsLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
        ])
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
    
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            self.classesLabel.text = ""
        }
        
        DispatchQueue.global().async {
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
    }

    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        super.captureOutput(output, didOutput: sampleBuffer, from: connection)
        CMSampleBufferGetImageBuffer(sampleBuffer).map(self.detect)
    }
}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
