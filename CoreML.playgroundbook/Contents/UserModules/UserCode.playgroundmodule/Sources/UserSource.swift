import Vision
import CoreML

public func compileModel(at url: URL) throws -> VNCoreMLModel {
    return try compileModel(at: url, configuration: MLModelConfiguration())
}

public func compileModel(at url: URL, configuration: MLModelConfiguration) throws -> VNCoreMLModel {
    let compiledUrl = try MLModel.compileModel(at: url)
    let mlModel = try MLModel(contentsOf: compiledUrl, configuration: configuration)
    return try VNCoreMLModel(for: mlModel)
}

public extension DispatchTime {
    public func durationSec(since: DispatchTime) -> Float64 {
        let elapsedNano = self.uptimeNanoseconds - since.uptimeNanoseconds
        return Float64(elapsedNano) / 1_000_000_000
    }
}
