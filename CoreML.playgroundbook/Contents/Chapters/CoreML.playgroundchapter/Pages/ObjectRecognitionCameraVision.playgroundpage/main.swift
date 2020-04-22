import ARKit
import PlaygroundSupport
import UIKit
import Vision

// Parameters
// The model is from here: https://docs-assets.developer.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2Int8LUT.mlmodel
let config = MLModelConfiguration()
config.allowLowPrecisionAccumulationOnGPU = true
config.computeUnits = .all
let model = try! compileModel(at: #fileLiteral(resourceName: "MobileNetV2Int8LUT.mlmodel"), configuration: config)
let threshold: Float = 0.5

// ViewControllers
class ViewController: PreviewViewController {
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

        self.arView.session.delegate = self

        self.view.addSubview(self.classesLabel)

        NSLayoutConstraint.activate([
            self.classesLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.classesLabel.leadingAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.leadingAnchor),
            self.classesLabel.trailingAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.trailingAnchor),
        ])
    }

    func detect(imageBuffer: CVImageBuffer) {
        try! VNImageRequestHandler(cvPixelBuffer: imageBuffer).perform([self.request])
    }

    func processClassifications(for request: VNRequest, error: Error?) {
        self.classesLabel.text = ""

        request.results?
            .lazy
            .compactMap { $0 as? VNClassificationObservation }
            .filter { $0.confidence >= threshold }
            .forEach { cls in
                self.classesLabel.text?.append("\(cls.identifier): \(cls.confidence)\n")
            }
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        self.detect(imageBuffer: frame.capturedImage)
    }
}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
