import CoreML
import Vision
import UIKit
import AVFoundation
import CoreMedia
import PlaygroundSupport

// Parameters
let threshold: Float = 0.3

// Views
class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var imageView: UIImageView!
    private var label: UILabel!
    private var session: AVCaptureSession!
    
    private var request: VNCoreMLRequest!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.imageView = UIImageView()
        self.imageView.contentMode = .scaleAspectFit
        
        self.label = UILabel()
        self.label.textAlignment = .center
        self.label.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 1.0)
        self.label.text = "Nothing is detected."
        
        let stackView = UIStackView(arrangedSubviews: [self.imageView, self.label])
        stackView.axis = .vertical
        self.view = stackView
        
        self.setupCoreML()
        self.setupCamera()
    }
    
    private func setupCamera() {
        self.session = AVCaptureSession()
        self.session.sessionPreset = .hd1280x720
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera , for: .video, position: .back) else { fatalError() }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
        } catch let error {
            print(error)
        }
        
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            device.unlockForConfiguration()
        } catch let error {
            print(error)
        }
        
        let output = AVCaptureVideoDataOutput()
        if self.session.canAddOutput(output) {
            self.session.addOutput(output)
        }
        
        let cameraQueue = DispatchQueue(label: "Camera Queue")
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        output.setSampleBufferDelegate(self, queue: cameraQueue)
        output.alwaysDiscardsLateVideoFrames = true
        
        self.session.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let resultImage = ViewController.getImageFromSampleBuffer(sampleBuffer)
        
        DispatchQueue.main.async {
            self.imageView.image = resultImage
        }
        
        self.detect(image: resultImage)
    }
    
    private static func getImageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { fatalError() }
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0) else { fatalError() }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let newContext = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue
            ) else { fatalError() }
        
        guard let imageRef = newContext.makeImage() else { fatalError() }
        let resultImage = UIImage(cgImage: imageRef, scale: 1.0, orientation: .right)
        
        return resultImage
    }
    
    private func setupCoreML() {
        let modelUrl = #fileLiteral(resourceName: "MobileNet.mlmodel")
        do {
            let compiledUrl = try MLModel.compileModel(at: modelUrl)
            let model = try VNCoreMLModel(for: try MLModel(contentsOf: compiledUrl))
            self.request = VNCoreMLRequest(model: model) { request, error in
                guard let observations = request.results as? [VNClassificationObservation] else { fatalError() }
                if let best = observations.first {
                    DispatchQueue.main.async {
                        self.label.text = "\(best.identifier): \(best.confidence)"
                    }
                }
            }
        } catch let error {
            print(error)
        }
    }
    
    private func detect(image: UIImage) {
        // Object Recognition
        do {
            guard let ciImage = CIImage(image: image) else { fatalError() }
            try VNImageRequestHandler(ciImage: ciImage).perform([self.request])
        } catch let error {
            print(error)
        }
    }
}

PlaygroundPage.current.liveView = ViewController()

