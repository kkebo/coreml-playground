import Vision
import UIKit
import PlaygroundSupport

// Parameters
let uiImage = #imageLiteral(resourceName: "IMG_0032.JPG")
let threshold: Float = 0.5

// Views
let imageView = UIImageView(image: uiImage)
imageView.contentMode = .scaleAspectFit
let stackView = UIStackView(arrangedSubviews: [imageView])
stackView.axis = .vertical
PlaygroundPage.current.liveView = stackView

// Object Recognition
let model = try compileModel(at: #fileLiteral(resourceName: "MobileNet.mlmodel"))
let request = VNCoreMLRequest(model: model) { request, error in
    request.results?
        .lazy
        .compactMap { $0 as? VNClassificationObservation }
        .filter { $0.confidence >= threshold }
        .map {
            let label = UILabel()
            label.textAlignment = .center
            label.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 1.0)
            label.text = "\($0.identifier): \($0.confidence)"
            return label
        }
        .forEach { label in
            DispatchQueue.main.async {
                stackView.addArrangedSubview(label)
            }
        }
}
request.imageCropAndScaleOption = .scaleFill

guard let ciImage = CIImage(image: uiImage) else { fatalError() }
try VNImageRequestHandler(ciImage: ciImage).perform([request])
