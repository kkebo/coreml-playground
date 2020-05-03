import Accelerate
import CoreML
import UIKit
import Vision

public func compileModel(at url: URL) throws -> VNCoreMLModel {
    try compileModel(at: url, configuration: MLModelConfiguration())
}

public func compileModel(at url: URL, configuration: MLModelConfiguration) throws -> VNCoreMLModel {
    let compiledUrl = try MLModel.compileModel(at: url)
    let mlModel = try MLModel(contentsOf: compiledUrl, configuration: configuration)
    return try VNCoreMLModel(for: mlModel)
}

extension CGSize {
    public static func / (_ lhs: Self, _ rhs: Self) -> Self {
        Self(
            width: lhs.width / rhs.width,
            height: lhs.height / rhs.height
        )
    }
}

public func argmax(_ array: UnsafePointer<Double>, count: UInt) -> (Int, Double) {
    var maxValue: Double = 0
    var maxIndex: vDSP_Length = 0
    vDSP_maxviD(array, 1, &maxValue, &maxIndex, vDSP_Length(count))
    return (Int(maxIndex), maxValue)
}

extension CGImagePropertyOrientation {
    public init(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait:
            self = .right
        case .portraitUpsideDown:
            self = .left
        case .landscapeLeft:
            self = .down
        case .landscapeRight:
            self = .up
        default:
            self = .right
        }
    }
}

extension UIScreen {
    public var orientation: UIInterfaceOrientation {
        let point = self.coordinateSpace.convert(CGPoint.zero, to: self.fixedCoordinateSpace)
        switch (point.x, point.y) {
        case (0, 0):
            return .portrait
        case let (x, y) where x != 0 && y != 0:
            return .portraitUpsideDown
        case let (0, y) where y != 0:
            return .landscapeLeft
        case let (x, 0) where x != 0:
            return .landscapeRight
        default:
            return .unknown
        }
    }
}

public let coco_classes = [
    "person",
    "bicycle",
    "car",
    "motorbike",
    "aeroplane",
    "bus",
    "train",
    "truck",
    "boat",
    "traffic light",
    "fire hydrant",
    "stop sign",
    "parking meter",
    "bench",
    "bird",
    "cat",
    "dog",
    "horse",
    "sheep",
    "cow",
    "elephant",
    "bear",
    "zebra",
    "giraffe",
    "backpack",
    "umbrella",
    "handbag",
    "tie",
    "suitcase",
    "frisbee",
    "skis",
    "snowboard",
    "sports ball",
    "kite",
    "baseball bat",
    "baseball glove",
    "skateboard",
    "surfboard",
    "tennis racket",
    "bottle",
    "wine glass",
    "cup",
    "fork",
    "knife",
    "spoon",
    "bowl",
    "banana",
    "apple",
    "sandwich",
    "orange",
    "broccoli",
    "carrot",
    "hot dog",
    "pizza",
    "donut",
    "cake",
    "chair",
    "sofa",
    "pottedplant",
    "bed",
    "diningtable",
    "toilet",
    "tvmonitor",
    "laptop",
    "mouse",
    "remote",
    "keyboard",
    "cell phone",
    "microwave",
    "oven",
    "toaster",
    "sink",
    "refrigerator",
    "book",
    "clock",
    "vase",
    "scissors",
    "teddy bear",
    "hair drier",
    "toothbrush",
]
