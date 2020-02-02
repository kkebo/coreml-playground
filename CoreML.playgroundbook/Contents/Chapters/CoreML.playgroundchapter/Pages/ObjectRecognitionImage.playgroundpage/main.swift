import Vision
import UIKit
import PlaygroundSupport

// Parameters
// The model is from here: https://docs-assets.developer.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2Int8LUT.mlmodel
let model = try MLModel(contentsOf: try MLModel.compileModel(at: #fileLiteral(resourceName: "MobileNetV2Int8LUT.mlmodel")))
let inputName = "image"
let outputName = "classLabelProbs"
let uiImage = #imageLiteral(resourceName: "IMG_0032.JPG")
let threshold: Float = 0.5

// Views
let imageView = UIImageView(image: uiImage)
imageView.contentMode = .scaleAspectFit
let stackView = UIStackView(arrangedSubviews: [imageView])
stackView.axis = .vertical
PlaygroundPage.current.liveView = stackView

// Object Recognition
let imageConstraint = model.modelDescription
    .inputDescriptionsByName[inputName]!
    .imageConstraint!
let imageOptions: [MLFeatureValue.ImageOption: Any] = [
    .cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue
]
let featureValue = try MLFeatureValue(cgImage: uiImage.cgImage!, constraint: imageConstraint, options: imageOptions)
let featureProvider = try MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])
let result = try model.prediction(from: featureProvider)
result.featureValue(for: outputName)?
    .dictionaryValue
    .lazy
    .filter { $0.1.floatValue >= threshold }
    .sorted { $0.1.floatValue > $1.1.floatValue }
    .map { name, confidence in
        let label = UILabel()
        label.textAlignment = .center
        label.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 1.0)
        label.text = "\(name) \(confidence)"
        return label
    }
    .forEach { label in
        DispatchQueue.main.async {
            stackView.addArrangedSubview(label)
        }
    }