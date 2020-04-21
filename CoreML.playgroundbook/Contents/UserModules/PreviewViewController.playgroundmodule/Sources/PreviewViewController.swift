import ARKit
import PlaygroundSupport
import RealityKit
import UIKit

open class PreviewViewController: UIViewController {
    public lazy var arView: ARView = {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.session.run(AROrientationTrackingConfiguration())
        view.addSubview(self.flipCameraButton)
        return view
    }()
    lazy var flipCameraButton: UIButton = {
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
    var usingFrontCamera = false

    override open func viewDidLoad() {
        super.viewDidLoad()

        self.view = self.arView

        NSLayoutConstraint.activate([
            self.flipCameraButton.bottomAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.bottomAnchor),
            self.flipCameraButton.rightAnchor.constraint(equalTo: self.liveViewSafeAreaGuide.rightAnchor),
        ])
    }

    @objc func flipCamera(_ sender: UIButton) {
        UIView.transition(with: self.view, duration: 0.4, options: .transitionFlipFromLeft, animations: {
            let config = self.usingFrontCamera ? AROrientationTrackingConfiguration() : ARFaceTrackingConfiguration()
            self.arView.session.run(config)

            self.usingFrontCamera = !self.usingFrontCamera
        })
    }
}

extension PreviewViewController: PlaygroundLiveViewSafeAreaContainer {}
