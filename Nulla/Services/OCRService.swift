import Foundation
import Vision
import UIKit

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

    static func classifyObject(in image: UIImage, maxResults: Int = 5) async throws -> [ObjectCandidate] {
        guard let cgImage = image.cgImage else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
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
                let candidates = (request.results as? [VNClassificationObservation] ?? [])
                    .filter { $0.confidence > 0.05 }
                    .prefix(maxResults)
                    .map { ObjectCandidate(label: cleanLabel($0.identifier), confidence: $0.confidence) }
                resume(.success(Array(candidates)))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
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
