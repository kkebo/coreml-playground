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
        
        view.addSubview(self.classesLabel)
        view.addSubview(self.fpsLabel)
        view.addSubview(self.segmentedControl)
        view.addSubview(self.flipCameraButton)
        
        return view
    }()
    let classesLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 0.5)
        label.text = "Nothing is detected."
        return label
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
    let flipCameraButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: "flipCamera:", for: .touchUpInside)
        button.setAttributedTitle(
            NSAttributedString(
                string: "Flip",
                attributes: [
                    NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline),
                    NSAttributedString.Key.foregroundColor: UIColor.orange
                ]
            ),
            for: .normal
        )
        return button
    }()
    
    lazy var caps: [VideoCaptureDevice] = [
        {
            var cap = try! VideoCaptureDevice(preset: .photo, position: .back, mirrored: false)
            cap.delegate = self
            return cap
        }(),
        {
            var cap = try! VideoCaptureDevice(preset: .photo, position: .front, mirrored: true)
            cap.delegate = self
            return cap
        }(),
    ]
    var capId = 0
    var cap: VideoCaptureDevice {
        return self.caps[self.capId]
    }
    
    let model = try! compileModel(at: #fileLiteral(resourceName: "MobileNet.mlmodel"))
    lazy var request: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: self.model, completionHandler: self.processClassifications)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view = self.previewView
        
        NSLayoutConstraint.activate([
            self.classesLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.classesLabel.leadingAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.leadingAnchor),
            self.classesLabel.trailingAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.trailingAnchor),
            self.fpsLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.segmentedControl.topAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.topAnchor),
            self.segmentedControl.centerXAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.centerXAnchor),
            self.segmentedControl.leftAnchor.constraint(greaterThanOrEqualTo: self.liveViewSafeAreaGuide.leftAnchor),
            self.segmentedControl.rightAnchor.constraint(lessThanOrEqualTo: self.liveViewSafeAreaGuide.rightAnchor),
            self.flipCameraButton.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.flipCameraButton.rightAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.rightAnchor),
        ])
        
        self.cap.start()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
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
    
    @objc func flipCamera(_ sender: UIButton) {
        UIView.transition(with: self.view, duration: 0.4, options: .transitionFlipFromLeft, animations: {
            self.cap.stop()
            self.capId = self.capId == 0 ? 1 : 0
            self.cap.start()
        })
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
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            self.previewLayer.enqueue(sampleBuffer)
        }
        CMSampleBufferGetImageBuffer(sampleBuffer).map(self.detect)
    }
}

extension ViewController: PlaygroundLiveViewSafeAreaContainer {}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
