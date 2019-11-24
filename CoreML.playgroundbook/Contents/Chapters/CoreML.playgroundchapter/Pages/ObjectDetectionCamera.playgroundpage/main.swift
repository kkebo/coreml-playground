import Vision
import UIKit
import AVFoundation
import PlaygroundSupport
import PreviewViewController
import VideoCapture

// Parameters
let threshold: Float = 0.3

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

    let model = try! compileModel(at: #fileLiteral(resourceName: "MobileNetV2_SSDLite.mlmodel"))
    lazy var request: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: self.model, completionHandler: self.processDetections)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer.addSublayer(self.bboxLayer)
        self.view.addSubview(self.fpsLabel)

        NSLayoutConstraint.activate([
            self.fpsLabel.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
        ])

        self.cap
            .compactMap(CMSampleBufferGetImageBuffer)
            .sink(receiveValue: self.detect)
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

    func detect(imageBuffer: CVImageBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)

        let start = DispatchTime.now()
        try! handler.perform([self.request])
        let fps = 1 / DispatchTime.now().durationSec(since: start)
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
                .filter { $0.labels[0].confidence >= threshold }
                .forEach {
                    print($0.labels[0])

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

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
