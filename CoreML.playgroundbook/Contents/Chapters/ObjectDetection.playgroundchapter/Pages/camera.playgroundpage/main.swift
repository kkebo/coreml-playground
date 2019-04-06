import CoreML
import Vision
import UIKit
import AVFoundation
import PlaygroundSupport

// ViewControllers
class ViewController: UIViewController {
    var request: VNCoreMLRequest!
    let previewLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        return layer
    }()
    lazy var previewView: UIView = {
        let view = UIView()
        view.layer.addSublayer(self.previewLayer)
        return view
    }()
    lazy var cap = try! VideoCaptureDevice(preset: .hd1280x720)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view = self.previewView
        
        self.setupCoreML()
        
        self.cap.delegate = self
        self.cap.start()
    }
    
    override func viewWillLayoutSubviews() {
        self.previewLayer.frame = self.view.bounds
    }
    
    func setupCoreML() {
        let modelUrl = #fileLiteral(resourceName: "ObjectDetector.mlmodel")
        let compiledUrl = try! MLModel.compileModel(at: modelUrl)
        let model = try! VNCoreMLModel(for: try! MLModel(contentsOf: compiledUrl))
        self.request = VNCoreMLRequest(model: model) { request, error in
            request.results?.compactMap { $0 as? VNRecognizedObjectObservation }.forEach {
                print($0.labels[0])
                print($0.boundingBox)
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
        DispatchQueue.main.async {
            self.previewLayer.enqueue(sampleBuffer)
        }
        CMSampleBufferGetImageBuffer(sampleBuffer).map(self.detect)
    }
}

PlaygroundPage.current.wantsFullScreenLiveView = true
PlaygroundPage.current.liveView = ViewController()
