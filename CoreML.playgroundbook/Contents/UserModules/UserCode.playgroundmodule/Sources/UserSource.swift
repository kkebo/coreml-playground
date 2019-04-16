import AVFoundation

public struct VideoCaptureDevice {
    let session = AVCaptureSession()
    let output: AVCaptureVideoDataOutput = {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        return output
    }()
    let mirrored: Bool

    public init(preset: AVCaptureSession.Preset, position: AVCaptureDevice.Position, mirrored: Bool) throws {
        self.session.sessionPreset = preset
        self.mirrored = mirrored

        let device = getDefaultDevice(position: position)!
        try configureDevice(device: device).get()
        let input = try AVCaptureDeviceInput(device: device)

        if self.session.canAddInput(input) {
            self.session.addInput(input)
        }
        if self.session.canAddOutput(self.output) {
            self.session.addOutput(self.output)
        }
    }

    public func start() {
        if !self.session.isRunning {
            self.session.startRunning()
        }
    }

    public func stop() {
        if self.session.isRunning {
            self.session.stopRunning()
        }
    }
    
    public func setDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        if session.isRunning {
            self.session.stopRunning()
        }

        let queue = DispatchQueue(label: "cameraQueue")
        self.output.setSampleBufferDelegate(delegate, queue: queue)

        if let connection = self.output.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeLeft
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = self.mirrored
            }
        }
    }

    public func rotate(orientation: AVCaptureVideoOrientation) {
        if let connection = self.output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
    }
}

func getDefaultDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    if let device = AVCaptureDevice.default(.builtInDualCamera , for: .video, position: position) {
        return device
    } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera , for: .video, position: position) {
        return device
    } else {
        return nil
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

import Vision
import CoreML

public func compileModel(at url: URL) throws -> VNCoreMLModel {
    let compiledUrl = try MLModel.compileModel(at: url)
    let mlModel = try MLModel(contentsOf: compiledUrl)
    return try VNCoreMLModel(for: mlModel)
}

public extension DispatchTime {
    public func durationSec(since: DispatchTime) -> Float64 {
        let elapsedNano = self.uptimeNanoseconds - since.uptimeNanoseconds
        return Float64(elapsedNano) / 1_000_000_000
    }
}
