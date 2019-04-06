import CoreML
import Vision
import UIKit
import PlaygroundSupport

// Parameters
let uiImage = #imageLiteral(resourceName: "IMG_0032.JPG")
let threshold: Float = 0.3

// Views
let imageView = UIImageView(image: uiImage)
imageView.contentMode = .scaleAspectFit
let label = UILabel()
label.textAlignment = .center
label.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 1.0)
let stackView = UIStackView(arrangedSubviews: [imageView, label])
stackView.axis = .vertical
PlaygroundPage.current.liveView = stackView

// Object Recognition
let modelUrl = #fileLiteral(resourceName: "MobileNet.mlmodel")
let compiledUrl = try MLModel.compileModel(at: modelUrl)
let model = try VNCoreMLModel(for: try MLModel(contentsOf: compiledUrl))
let coremlRequest = VNCoreMLRequest(model: model) { request, error in
    guard let observations = request.results as? [VNClassificationObservation] else { fatalError() }
    observations.filter { $0.confidence >= threshold }.forEach {
        label.text = "\($0.identifier): \($0.confidence)"
    }
}

guard let ciImage = CIImage(image: uiImage) else { fatalError() }
try VNImageRequestHandler(ciImage: ciImage).perform([coremlRequest])
