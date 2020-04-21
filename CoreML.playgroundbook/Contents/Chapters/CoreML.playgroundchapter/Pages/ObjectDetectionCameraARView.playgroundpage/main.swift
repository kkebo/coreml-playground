import Vision
import UIKit
import ARKit
import RealityKit
import PlaygroundSupport
import VideoCapture

// Parameters
// The model is from here: https://docs-assets.developer.apple.com/coreml/models/Image/ObjectDetection/YOLOv3Tiny/YOLOv3TinyInt8LUT.mlmodel
let config = MLModelConfiguration()
config.allowLowPrecisionAccumulationOnGPU = true
config.computeUnits = .all
let model = try compileModel(at: #fileLiteral(resourceName: "YOLOv3TinyInt8LUT.mlmodel"), configuration: config)
model.featureProvider = try MLDictionaryFeatureProvider(dictionary: [
    "iouThreshold": 0.5,
    "confidenceThreshold": 0.3,
])

// ViewControllers
class ViewController: UIViewController {
    lazy var arView: ARView = {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.session.delegate = self
        view.session.run(AROrientationTrackingConfiguration())
        view.layer.addSublayer(self.bboxLayer)
        view.addSubview(self.fpsLabel)
        view.addSubview(self.flipCameraButton)
        return view
    }()
    let fpsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = #colorLiteral(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        label.text = "fps: -"
        return label
    }()
    let bboxLayer = CALayer()
    lazy var flipCameraButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(self.flipCamera), for: .touchUpInside)
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
    var usingFrontCamera = false

    lazy var request: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: model, completionHandler: self.processDetections)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view = self.arView

        NSLayoutConstraint.activate([
            self.fpsLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.flipCameraButton.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.flipCameraButton.rightAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.rightAnchor),
        ])
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.bboxLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
    }

    @objc func flipCamera(_ sender: UIButton) {
        UIView.transition(with: self.view, duration: 0.4, options: .transitionFlipFromLeft, animations: {
            let config = self.usingFrontCamera ? AROrientationTrackingConfiguration() : ARFaceTrackingConfiguration()
            self.arView.session.run(config)

            self.usingFrontCamera = !self.usingFrontCamera
        })
    }

    func detect(imageBuffer: CVImageBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)

        let start = Date()
        try! handler.perform([self.request])
        let fps = 1 / Date().timeIntervalSince(start)
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
                .forEach {
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

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let imageBuffer = frame.capturedImage

        let size = CVImageBufferGetDisplaySize(imageBuffer)
        let scale = self.view.bounds.size / size
        let maxScale = fmax(scale.width, scale.height)
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.bboxLayer.setAffineTransform(CGAffineTransform(scaleX: maxScale, y: -maxScale))
        self.bboxLayer.bounds = CGRect(origin: .zero, size: size)
        self.bboxLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        CATransaction.commit()

        self.detect(imageBuffer: imageBuffer)
    }
}

extension ViewController: PlaygroundLiveViewSafeAreaContainer {}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()