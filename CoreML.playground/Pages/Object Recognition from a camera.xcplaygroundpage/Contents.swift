import CoreML
import Vision
import UIKit
import AVFoundation
import CoreMedia
import PlaygroundSupport

// Parameters
let threshold: Float = 0.3

// ViewControllers
class ViewController: UIViewController {
    lazy var session: AVCaptureSession = {
        let deviceResult = getDefaultDevice()
        var device: AVCaptureDevice
        switch deviceResult {
        case let .success(value):
            device = value
        case let .failure(error):
            fatalError(error.localizedDescription)
        }
        if case let .failure(error) = configureDevice(device: device) {
            fatalError(error.localizedDescription)
        }
        
        let sessionResult = self.createSession(device: device)
        switch sessionResult {
        case let .success(session):
            return session
        case let .failure(error):
            fatalError(error.localizedDescription)
        }
    }()
    var request: VNCoreMLRequest!
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: self.session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    lazy var previewView: UIView = {
        let view = UIView()
        view.layer.addSublayer(self.previewLayer)
        return view
    }()
    let label: UILabel = {
        let view = UILabel()
        view.textAlignment = .center
        view.backgroundColor = #colorLiteral(red: 0.258823543787003, green: 0.756862759590149, blue: 0.968627452850342, alpha: 1.0)
        view.text = "Nothing is detected."
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let stackView = UIStackView(arrangedSubviews: [self.previewView, self.label])
        stackView.axis = .vertical
        self.view = stackView
        
        self.setupCoreML()
        self.session.startRunning()
    }
    
    override func viewWillLayoutSubviews() {
        self.previewLayer.frame = self.view.bounds
    }
    
    func createSession(device: AVCaptureDevice) -> Result<AVCaptureSession, Error> {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720
        
        let inputResult = Result { try AVCaptureDeviceInput(device: device) }
        switch inputResult {
        case let .success(input) where session.canAddInput(input):
            session.beginConfiguration()
            session.addInput(input)
            session.commitConfiguration()
        case let .failure(error):
            return .failure(error)
        default: break
        }
        
        let output = AVCaptureVideoDataOutput()
        if session.canAddOutput(output) {
            let cameraQueue = DispatchQueue(label: "Camera Queue")
            
            session.beginConfiguration()
            session.addOutput(output)
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: cameraQueue)
            output.alwaysDiscardsLateVideoFrames = true
            if let connection = output.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .landscapeLeft
                }
            }
            session.commitConfiguration()
        }
        
        return .success(session)
    }
    
    func setupCoreML() {
        let modelUrl = #fileLiteral(resourceName: "MobileNet.mlmodel")
        let compiledUrl = try! MLModel.compileModel(at: modelUrl)
        let model = try! VNCoreMLModel(for: try! MLModel(contentsOf: compiledUrl))
        self.request = VNCoreMLRequest(model: model) { request, error in
            if let observations = request.results as? [VNClassificationObservation], let best = observations.first {
                DispatchQueue.main.async {
                    self.label.text = "\(best.identifier): \(best.confidence)"
                }
            }
        }
    }
    
    func detect(imageBuffer: CVImageBuffer) {
        // Object Recognition
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)
        let result = Result { try handler.perform([self.request]) }
        if case let .failure(error) = result {
            fatalError(error.localizedDescription)
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            DispatchQueue.main.async {
                self.previewLayer.contents = buffer
            }
            
            self.detect(imageBuffer: buffer)
        }
    }
}

enum GetDefaultDeviceError: Error {
    case unavailable
}

func getDefaultDevice() -> Result<AVCaptureDevice, GetDefaultDeviceError> {
    if let device = AVCaptureDevice.default(.builtInDualCamera , for: .video, position: .back) {
        return .success(device)
    } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera , for: .video, position: .back) {
        return .success(device)
    } else {
        return .failure(.unavailable)
    }
}

enum ConfigureDeviceError: Error {
    case formatNotFound
    case deviceLockFailed
}

func configureDevice(device: AVCaptureDevice) -> Result<(), ConfigureDeviceError> {
    var bestFormat: AVCaptureDevice.Format? = nil
    var bestFrameRateRange: AVFrameRateRange? = nil
    for format in device.formats {
        for range in format.videoSupportedFrameRateRanges {
            if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? -Float64.greatestFiniteMagnitude {
                bestFormat = format
                bestFrameRateRange = range
            }
        }
    }
    
    guard let format = bestFormat, let range = bestFrameRateRange else {
        return .failure(.formatNotFound)
    }
    
    let lock = Result { try device.lockForConfiguration() }
    guard case .success = lock else {
        return .failure(.deviceLockFailed)
    }
    
    device.activeFormat = format
    device.activeVideoMinFrameDuration = range.maxFrameDuration
    device.activeVideoMaxFrameDuration = range.maxFrameDuration
    device.unlockForConfiguration()
    
    return .success(())
}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()

