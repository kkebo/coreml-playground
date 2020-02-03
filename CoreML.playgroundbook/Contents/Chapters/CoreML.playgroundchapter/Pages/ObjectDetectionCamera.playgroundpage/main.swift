import Vision
import UIKit
import AVFoundation
import VideoToolbox
import PlaygroundSupport
import PreviewViewController
import VideoCapture

// Parameters
// The model is from here: https://docs-assets.developer.apple.com/coreml/models/Image/ObjectDetection/YOLOv3Tiny/YOLOv3TinyInt8LUT.mlmodel
let config = MLModelConfiguration()
config.allowLowPrecisionAccumulationOnGPU = true
config.computeUnits = .all
let model = try MLModel(contentsOf: try MLModel.compileModel(at: #fileLiteral(resourceName: "YOLOv3TinyInt8LUT.mlmodel")), configuration: config)
let inputName = "image"
let iouThresholdName = "iouThreshold"
let confidenceThresholdName = "confidenceThreshold"
let outputName = "coordinates"
let iouThreshold = 0.5
let confidenceThreshold = 0.3
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
    let bboxLayer = CALayer()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer.addSublayer(self.bboxLayer)
        self.view.addSubview(self.fpsLabel)

        NSLayoutConstraint.activate([
            self.fpsLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
        ])

        self.cap
            .compactMap(CMSampleBufferGetImageBuffer)
            .tryMap { imageBuffer in
                var cgImage: CGImage!
                VTCreateCGImageFromCVPixelBuffer(imageBuffer, options: nil, imageOut: &cgImage)
                return try MLFeatureValue(cgImage: cgImage, constraint: imageConstraint, options: imageOptions)
            }
            .tryMap {
                try MLDictionaryFeatureProvider(dictionary: [
                    inputName: $0,
                    iouThresholdName: iouThreshold,
                    confidenceThresholdName: confidenceThreshold,
                ])
            }
            .mapError { _ in fatalError() }
            .map(self.detect)
            .sink(receiveValue: self.drawResult)
            .store(in: &self.cancellables)

        self.cap
            .compactMap(CMSampleBufferGetImageBuffer)
            .map(CVImageBufferGetDisplaySize)
            .map { size -> (CGSize, CGFloat) in
                let scale = self.view.bounds.size / size
                return (size, fmin(scale.width, scale.height))
            }
            .sink { size, scale in
                CATransaction.begin()
                CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
                self.bboxLayer.setAffineTransform(CGAffineTransform(scaleX: scale, y: -scale))
                self.bboxLayer.bounds = CGRect(origin: .zero, size: size)
                self.bboxLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
                CATransaction.commit()
            }
            .store(in: &self.cancellables)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.bboxLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
    }

    func detect(input: MLFeatureProvider) -> MLFeatureProvider {
        let start = DispatchTime.now()
        let result = try! model.prediction(from: input)
        let fps = 1 / DispatchTime.now().durationSec(since: start)
        DispatchQueue.main.async {
            self.fpsLabel.text = "fps: \(fps)"
        }
        return result
    }

    func drawResult(result: MLFeatureProvider) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)

        // Remove all bboxes
        self.bboxLayer.sublayers = nil

        let coordinates = result.featureValue(for: "coordinates")!
            .multiArrayValue!
        let confidence = result.featureValue(for: "confidence")!
            .multiArrayValue!
        let num_det = coordinates.shape[0].uintValue

        let imgSize = self.bboxLayer.bounds.size

        for i in 0..<num_det {
            let i = i as NSNumber
            let cx = coordinates[[i, 0]].doubleValue
            let cy = coordinates[[i, 1]].doubleValue
            let w = coordinates[[i, 2]].doubleValue
            let h = coordinates[[i, 3]].doubleValue
            let rect = CGRect(x: cx - w / 2, y: 1 - cy - h / 2, width: w, height: h)
            let bbox = VNImageRectForNormalizedRect(rect, Int(imgSize.width), Int(imgSize.height))

            let num_cls = confidence.shape[1].uintValue
            let featurePointer = UnsafePointer<Double>(OpaquePointer(confidence.dataPointer.advanced(by: i.intValue)))
            let (id, conf) = argmax(featurePointer, count: num_cls)
            let cls = coco_classes[id]

            // Render a bounding box
            let shapeLayer = CALayer()
            shapeLayer.borderColor = #colorLiteral(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            shapeLayer.borderWidth = 2
            shapeLayer.bounds = bbox
            shapeLayer.position = CGPoint(x: bbox.midX, y: bbox.midY)

            // Render a description
            let textLayer = CATextLayer()
            textLayer.string = "\(cls): \(conf)"
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

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
