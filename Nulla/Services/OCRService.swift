import Foundation
import Vision
import UIKit
import CoreImage

struct ObjectCandidate: Sendable {
    let label: String
    let confidence: Float
}

struct OCRService {
    static func recognizeText(in image: UIImage, languageCodes: [String] = ["zh-Hans", "de", "en"]) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            // Vision can report a failure both via the request's completion
            // handler and by throwing from perform(_:) — guard against
            // resuming the continuation twice.
            var didResume = false
            func resume(_ result: Result<[String], Error>) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    resume(.failure(error))
                    return
                }
                let strings = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                resume(.success(strings))
            }
            request.recognitionLanguages = languageCodes
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resume(.failure(error))
            }
        }
    }

    static func classifyObject(in image: UIImage, maxResults: Int = 5) async throws -> (candidates: [ObjectCandidate], subjectImage: UIImage?) {
        guard let cgImage = image.cgImage else { return ([], nil) }

        // Attempt to isolate the main subject before classification so the
        // classifier scores the object rather than the background.
        let extracted = try? await extractSubject(from: cgImage)
        let subjectCGImage = extracted ?? cgImage

        let candidates: [ObjectCandidate] = try await withCheckedThrowingContinuation { continuation in
            // Vision can report a failure both via the request's completion
            // handler and by throwing from perform(_:) — guard against
            // resuming the continuation twice.
            var didResume = false
            func resume(_ result: Result<[ObjectCandidate], Error>) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let request = VNClassifyImageRequest { request, error in
                if let error {
                    resume(.failure(error))
                    return
                }
                let results = (request.results as? [VNClassificationObservation] ?? [])
                    .filter { $0.confidence > 0.05 }
                    .prefix(maxResults)
                    .map { ObjectCandidate(label: cleanLabel($0.identifier), confidence: $0.confidence) }
                resume(.success(Array(results)))
            }

            let handler = VNImageRequestHandler(cgImage: subjectCGImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resume(.failure(error))
            }
        }

        return (candidates, extracted.map { UIImage(cgImage: $0) })
    }

    // Extracts the foreground subject using the same instance-mask API that
    // powers the Photos sticker feature. Returns nil if no clear subject is found,
    // so the caller can fall back to the full image.
    private static func extractSubject(from cgImage: CGImage) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            func resume(_ result: Result<CGImage, Error>) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNGenerateForegroundInstanceMaskRequest { req, error in
                if let error {
                    resume(.failure(error))
                    return
                }
                guard let observation = (req.results as? [VNInstanceMaskObservation])?.first else {
                    resume(.failure(SubjectExtractionError.noSubjectFound))
                    return
                }
                do {
                    let pixelBuffer = try observation.generateMaskedImage(
                        ofInstances: observation.allInstances,
                        from: handler,
                        croppedToInstancesExtent: true
                    )
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    let context = CIContext()
                    guard let result = context.createCGImage(ciImage, from: ciImage.extent) else {
                        resume(.failure(SubjectExtractionError.conversionFailed))
                        return
                    }
                    resume(.success(result))
                } catch {
                    resume(.failure(error))
                }
            }

            do {
                try handler.perform([request])
            } catch {
                resume(.failure(error))
            }
        }
    }

    // ImageNet identifiers look like "African_leopard, leopard, Panthera_pardus"
    // Take the first synonym and make it human-readable.
    private static func cleanLabel(_ identifier: String) -> String {
        let first = identifier.split(separator: ",").first.map(String.init) ?? identifier
        let cleaned = first.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "_", with: " ")
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
}

private enum SubjectExtractionError: Error {
    case noSubjectFound
    case conversionFailed
}
