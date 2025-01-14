import ARKit
import PlaygroundSupport
import UIKit
import Vision

// Parameters
// The model is from here: https://docs-assets.developer.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2Int8LUT.mlmodel
let config = MLModelConfiguration()
config.allowLowPrecisionAccumulationOnGPU = true
config.computeUnits = .all
let model = try MLModel(contentsOf: try MLModel.compileModel(at: #fileLiteral(resourceName: "MobileNetV2Int8LUT.mlmodel")), configuration: config)
let inputName = "image"
let outputName = "classLabelProbs"
let threshold: Float = 0.5
let imageConstraint = model.modelDescription
    .inputDescriptionsByName[inputName]!
    .imageConstraint!
let imageOptions: [MLFeatureValue.ImageOption: Any] = [
    .cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue
]

// ViewControllers
final class ViewController: PreviewViewController {
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

    override func viewDidLoad() {
        super.viewDidLoad()

        self.arView.session.delegateQueue = .global(qos: .userInteractive)
        self.arView.session.delegate = self

        self.view.addSubview(self.classesLabel)
        self.view.addSubview(self.fpsLabel)

        NSLayoutConstraint.activate([
            self.classesLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.classesLabel.leadingAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.leadingAnchor),
            self.classesLabel.trailingAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.trailingAnchor),
            self.fpsLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
        ])
    }

    func detect(input: MLFeatureProvider) -> MLFeatureProvider {
        let start = Date()
        let result = try! model.prediction(from: input)
        let fps = 1 / Date().timeIntervalSince(start)
        DispatchQueue.main.async {
            self.fpsLabel.text = "fps: \(fps)"
        }
        return result
    }

    func drawResult(result: MLFeatureProvider) {
        DispatchQueue.main.async {
            self.classesLabel.text = ""
        }

        result.featureValue(for: outputName)?
            .dictionaryValue
            .lazy
            .filter { $0.1.floatValue >= threshold }
            .sorted { $0.1.floatValue > $1.1.floatValue }
            .forEach { name, confidence in
                DispatchQueue.main.async {
                    self.classesLabel.text?.append("\(name): \(confidence)\n")
                }
            }
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let imageBuffer = frame.capturedImage

        let orientation = CGImagePropertyOrientation(interfaceOrientation: UIScreen.main.orientation)
        let ciImage = CIImage(cvPixelBuffer: imageBuffer).oriented(orientation)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!

        let featureValue = try! MLFeatureValue(cgImage: cgImage, constraint: imageConstraint, options: imageOptions)
        let input = try! MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])

        let output = self.detect(input: input)
        self.drawResult(result: output)
    }
}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
