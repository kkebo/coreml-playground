import Vision
import UIKit
import AVFoundation
import VideoToolbox
import PlaygroundSupport
import PreviewViewController

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

        self.cap
            .compactMap(CMSampleBufferGetImageBuffer)
            .sink(receiveValue: self.detect)
            .store(in: &self.cancellables)
    }

    func detect(imageBuffer: CVImageBuffer) {
        let featureValue: MLFeatureValue = {
            var cgImage: CGImage!
            VTCreateCGImageFromCVPixelBuffer(imageBuffer, options: nil, imageOut: &cgImage)
            return try! MLFeatureValue(cgImage: cgImage, constraint: imageConstraint, options: imageOptions)
        }()
        let featureProvider = try! MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])

        let start = DispatchTime.now()
        let result = try! model.prediction(from: featureProvider)
        let fps = 1 / DispatchTime.now().durationSec(since: start)
        DispatchQueue.main.async {
            self.fpsLabel.text = "fps: \(fps)"
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

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
