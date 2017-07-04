import CoreML
import Vision
import UIKit
import PlaygroundSupport

// Parameters
let uiImage = #imageLiteral(resourceName: "IMG_0032.JPG")
let threshold: Float = 0.3

// Views
let imageView = UIImageView(image: uiImage)
let stackView = UIStackView(arrangedSubviews: [imageView])
stackView.axis = .vertical
PlaygroundPage.current.liveView = stackView

// Object Detection
guard let mlmodelcFile = Bundle.main.url(forResource: "Inceptionv3", withExtension: "mlmodelc") else { fatalError() }
let model = try VNCoreMLModel(for: try MLModel(contentsOf: mlmodelcFile))
let coremlRequest = VNCoreMLRequest(model: model) { request, error in
    guard let observations = request.results as? [VNClassificationObservation] else { fatalError() }
    observations.filter { $0.confidence >= threshold }.forEach {
        let label = UILabel()
        label.textAlignment = .center
        label.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 1.0)
        label.text = "\($0.identifier): \($0.confidence)"
        DispatchQueue.main.async {
            stackView.addArrangedSubview(label)
        }
    }
}

guard let ciImage = CIImage(image: uiImage) else { fatalError() }
try VNImageRequestHandler(ciImage: ciImage).perform([coremlRequest])
