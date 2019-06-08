import UIKit
import AVFoundation
import PlaygroundSupport
import VideoCapture

open class PreviewViewController: UIViewController {
    let previewLayer = AVSampleBufferDisplayLayer()
    lazy var previewView: UIView = {
        let view = UIView()
        
        view.layer.addSublayer(self.previewLayer)
        
        view.addSubview(self.segmentedControl)
        view.addSubview(self.flipCameraButton)
        
        return view
    }()
    lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["portrait", "portraitUpsideDown", "landscapeRight", "landscapeLeft"])
        control.selectedSegmentIndex = 3
        control.addTarget(self, action: #selector(self.rotateCamera), for: .valueChanged)
        
        control.translatesAutoresizingMaskIntoConstraints = false
        control.backgroundColor = .clear
        control.tintColor = .clear
        control.setTitleTextAttributes(
            [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline),
                NSAttributedString.Key.foregroundColor: UIColor.lightGray
            ],
            for: .normal
        )
        control.setTitleTextAttributes(
            [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline),
                NSAttributedString.Key.foregroundColor: UIColor.orange
            ],
            for: .selected
        )
        
        return control
    }()
    let flipCameraButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(self.flipCamera), for: .touchUpInside)
        button.setAttributedTitle(
            NSAttributedString(
                string: "Flip",
                attributes: [
                    NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline),
                    NSAttributedString.Key.foregroundColor: UIColor.orange
                ]
            ),
            for: .normal
        )
        return button
    }()
    
    lazy var caps: [VideoCaptureDevice] = [
        {
            let cap = try! VideoCaptureDevice(preset: .photo, position: .back, mirrored: false)
            cap.setDelegate(self)
            return cap
        }(),
        {
            let cap = try! VideoCaptureDevice(preset: .photo, position: .front, mirrored: true)
            cap.setDelegate(self)
            return cap
        }(),
    ]
    var capId = 0
    var cap: VideoCaptureDevice {
        return self.caps[self.capId]
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.view = self.previewView
        
        NSLayoutConstraint.activate([
            self.segmentedControl.topAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.topAnchor),
            self.segmentedControl.centerXAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.centerXAnchor),
            self.flipCameraButton.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.flipCameraButton.rightAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.rightAnchor),
        ])
        
        self.cap.start()
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.previewLayer.frame = self.view.bounds
    }
    
    @objc func rotateCamera(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            self.cap.rotate(orientation: .portrait)
        case 1:
            self.cap.rotate(orientation: .portraitUpsideDown)
        case 2:
            self.cap.rotate(orientation: .landscapeRight)
        case 3:
            self.cap.rotate(orientation: .landscapeLeft)
        default:
            break
        }
    }
    
    @objc func flipCamera(_ sender: UIButton) {
        UIView.transition(with: self.view, duration: 0.4, options: .transitionFlipFromLeft, animations: {
            self.cap.stop()
            self.capId = self.capId == 0 ? 1 : 0
            self.cap.start()
        })
    }
}

extension PreviewViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    open func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.previewLayer.enqueue(sampleBuffer)
    }
}

extension PreviewViewController: PlaygroundLiveViewSafeAreaContainer {}
