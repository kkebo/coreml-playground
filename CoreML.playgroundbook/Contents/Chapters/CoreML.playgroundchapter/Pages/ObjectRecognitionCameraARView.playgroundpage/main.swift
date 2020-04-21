import Vision
import UIKit
import ARKit
import RealityKit
import PlaygroundSupport

// Parameters
// The model is from here: https://docs-assets.developer.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2Int8LUT.mlmodel
let config = MLModelConfiguration()
config.allowLowPrecisionAccumulationOnGPU = true
config.computeUnits = .all
let model = try! compileModel(at: #fileLiteral(resourceName: "MobileNetV2Int8LUT.mlmodel"), configuration: config)
let threshold: Float = 0.5

// ViewControllers
class ViewController: UIViewController {
    lazy var arView: ARView = {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.session.delegate = self
        view.session.run(AROrientationTrackingConfiguration())
        view.addSubview(self.classesLabel)
        view.addSubview(self.fpsLabel)
        return view
    }()
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

    lazy var request: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: model, completionHandler: self.processClassifications)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view = self.arView

        NSLayoutConstraint.activate([
            self.classesLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.classesLabel.leadingAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.leadingAnchor),
            self.classesLabel.trailingAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.trailingAnchor),
            self.fpsLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
        ])
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

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        self.detect(imageBuffer: frame.capturedImage)
    }
}

extension ViewController: PlaygroundLiveViewSafeAreaContainer {}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
