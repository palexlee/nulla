import SwiftUI
import SwiftData
import PhotosUI
import Translation

struct CameraView: View {
    let language: Language
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    enum CaptureMode { case text, object }

    @State private var captureMode: CaptureMode = .text
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var detectedWords: [String] = []
    @State private var curatedWords: [String] = []
    @State private var selectedWords: Set<String> = []
    @State private var objectCandidates: [ObjectCandidate] = []
    @State private var objectSubjectImage: UIImage?
    @State private var objectEnglishLabel: String = ""
    @State private var objectForeignLabel: String = ""
    @State private var objectTranslations: [String: String] = [:]
    @State private var objectTranslationConfig: TranslationSession.Configuration?
    @State private var manualWord: String = ""
    @State private var selectedImage: UIImage?
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var showWordReview = false
    @State private var showAddCardForObject = false
    @State private var showCameraCapture = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var reviewWordCount: Int {
        selectedWords.count + (manualWord.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)

                segmentControl
                    .padding(.bottom, 12)

                if let image = selectedImage {
                    imagePreview(image)
                } else {
                    photoPickerPlaceholder
                }

                if captureMode == .text {
                    if !curatedWords.isEmpty { wordPickerList }
                    if selectedImage != nil { manualWordSection }
                    if reviewWordCount > 0 {
                        reviewButton
                    }
                } else if captureMode == .object, !objectCandidates.isEmpty {
                    objectResultView
                }

                Spacer()
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadPhoto(item) }
        }
        .sheet(isPresented: $showWordReview) {
            CameraWordListView(
                words: Array(selectedWords),
                language: language,
                thumbnailData: selectedImage.flatMap { resize($0, to: CGSize(width: 80, height: 80)) }?.jpegData(compressionQuality: 0.7),
                onSaved: { dismiss() }
            )
        }
        .sheet(isPresented: $showAddCardForObject) {
            AddCardView(
                language: language,
                prefillWord: objectEnglishLabel.isEmpty ? nil : objectEnglishLabel,
                prefillForeignWord: objectForeignLabel.isEmpty ? nil : objectForeignLabel,
                source: .camera,
                sourceThumbnailData: (objectSubjectImage ?? selectedImage).flatMap { resize($0, to: CGSize(width: 80, height: 80)) }?.jpegData(compressionQuality: 0.7),
                onSaved: { dismiss() }
            )
        }
        .sheet(isPresented: $showCameraCapture) {
            CameraCapturePicker { image in
                selectedImage = image
                Task { await processImage(image) }
            }
            .ignoresSafeArea()
        }
        .translationTask(objectTranslationConfig) { session in
            let requests = objectCandidates.map { TranslationSession.Request(sourceText: $0.label) }
            guard let responses = try? await session.translations(from: requests) else { return }
            for (candidate, response) in zip(objectCandidates, responses) {
                objectTranslations[candidate.label] = response.targetText
            }
            if let first = objectCandidates.first {
                objectEnglishLabel = first.label
                objectForeignLabel = objectTranslations[first.label] ?? first.label
            }
        }
    }

    // MARK: Header

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Cancel").manrope(13, .semibold).foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Scan").manrope(15, .heavy).foregroundStyle(Theme.ink)
            Spacer()
            Text("·").manrope(13, .semibold).foregroundStyle(Theme.surface2)
        }
    }

    // MARK: Segment

    private var segmentControl: some View {
        HStack(spacing: 0) {
            segButton("Text · OCR", mode: .text)
            segButton("Object", mode: .object)
        }
        .padding(3)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func segButton(_ label: String, mode: CaptureMode) -> some View {
        let active = captureMode == mode
        return Button { captureMode = mode } label: {
            Text(label)
                .manrope(13, active ? .bold : .semibold)
                .foregroundStyle(active ? Theme.ink : Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Theme.card)
                            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: Image areas

    private var photoPickerPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: captureMode == .text ? "doc.text.viewfinder" : "camera.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(Theme.muted)
            Text(captureMode == .text ? "Scan text to find words" : "Identify an object")
                .manrope(14, .medium).foregroundStyle(Theme.muted)

            HStack(spacing: 10) {
                if cameraAvailable {
                    Button {
                        showCameraCapture = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .manrope(13, .bold).foregroundStyle(Theme.onGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.green, in: RoundedRectangle(cornerRadius: Theme.rPill))
                    }
                    .buttonStyle(.plain)
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .manrope(13, .bold).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rPill))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 220)
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func imagePreview(_ image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if isProcessing {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .frame(maxHeight: 200)
                    .overlay { ProgressView().tint(.white) }
            }
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .topTrailing) {
            Menu {
                if cameraAvailable {
                    Button {
                        showCameraCapture = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            } label: {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .padding(8)
                    .background(Theme.surface, in: Circle())
            }
            .padding(.trailing, 28)
        }
    }

    // MARK: Text mode

    private var wordPickerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SUGGESTED WORDS")
                    .manrope(11, .bold).tracking(0.4).foregroundStyle(Theme.muted)
                Spacer()
                if detectedWords.count > curatedWords.count {
                    Button("Show all \(detectedWords.count)") {
                        curatedWords = detectedWords
                    }
                    .manrope(11.5, .bold).foregroundStyle(Theme.green)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(curatedWords, id: \.self) { word in
                    WordPickerRow(
                        word: word,
                        isSelected: selectedWords.contains(word)
                    ) {
                        if selectedWords.contains(word) {
                            selectedWords.remove(word)
                        } else {
                            selectedWords.insert(word)
                        }
                    }
                    Rectangle()
                        .fill(Theme.surface2)
                        .frame(height: 1)
                        .padding(.leading, 20)
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)

            if !curatedWords.isEmpty {
                Button {
                    if selectedWords.count == curatedWords.count {
                        selectedWords = []
                    } else {
                        selectedWords = Set(curatedWords)
                    }
                } label: {
                    Text(selectedWords.count == curatedWords.count ? "Deselect all" : "Select all")
                        .manrope(11.5, .bold).foregroundStyle(Theme.green)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 12)
    }

    private var manualWordSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(curatedWords.isEmpty ? "Type a word to add" : "Or add a word manually")
                .manrope(11, .semibold).foregroundStyle(Theme.muted)
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                TextField("Word in \(language.displayName)", text: $manualWord)
                    .manrope(13, .medium).foregroundStyle(Theme.ink)
                    .tint(Theme.green)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.surface2, lineWidth: 1.5)
                    )
                Button {
                    let word = manualWord.trimmingCharacters(in: .whitespaces)
                    guard !word.isEmpty else { return }
                    selectedWords.insert(word)
                    if !curatedWords.contains(word) { curatedWords.append(word) }
                    manualWord = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.green)
                }
                .disabled(manualWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, curatedWords.isEmpty ? 0 : 8)
    }

    private var reviewButton: some View {
        let count = reviewWordCount
        return Button { prepareWordReview() } label: {
            Text("Review \(count) card\(count == 1 ? "" : "s") →")
                .manrope(14, .bold).foregroundStyle(Theme.onGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: Theme.rPill))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    // MARK: Object mode

    private var objectResultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHAT DID YOU PHOTOGRAPH?")
                .manrope(11, .bold).tracking(0.4).foregroundStyle(Theme.muted)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(objectCandidates, id: \.label) { candidate in
                    objectCandidateRow(candidate)
                    Rectangle()
                        .fill(Theme.surface2)
                        .frame(height: 1)
                        .padding(.leading, 20)
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("Or type it yourself")
                    .manrope(11, .semibold).foregroundStyle(Theme.muted)
                    .padding(.horizontal, 20)
                HStack(spacing: 10) {
                    TextField("Word in \(language.displayName)", text: $objectForeignLabel)
                        .manrope(13, .medium).foregroundStyle(Theme.ink)
                        .tint(Theme.green)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.surface2, lineWidth: 1.5)
                        )
                }
                .padding(.horizontal, 20)
            }

            Button {
                showAddCardForObject = true
            } label: {
                Text(objectForeignLabel.isEmpty ? "Add to deck" : "Add \"\(objectForeignLabel)\" to deck")
                    .manrope(14, .bold)
                    .foregroundStyle(objectForeignLabel.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.muted : Theme.onGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        objectForeignLabel.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.surface : Theme.green,
                        in: RoundedRectangle(cornerRadius: Theme.rPill)
                    )
            }
            .buttonStyle(.plain)
            .disabled(objectForeignLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }

    private func objectCandidateRow(_ candidate: ObjectCandidate) -> some View {
        let translated = objectTranslations[candidate.label]
        let displayLabel = translated ?? candidate.label
        let isSelected = objectEnglishLabel == candidate.label
        return Button {
            objectEnglishLabel = candidate.label
            objectForeignLabel = objectTranslations[candidate.label] ?? candidate.label
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.green : Color.clear)
                        .frame(width: 23, height: 23)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.onGreen)
                    } else {
                        Circle()
                            .stroke(Theme.surface2, lineWidth: 1.5)
                            .frame(width: 23, height: 23)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayLabel)
                        .manrope(16, .semibold)
                        .foregroundStyle(isSelected ? Theme.ink : Theme.muted)
                    if translated != nil {
                        Text(candidate.label)
                            .manrope(12, .medium)
                            .foregroundStyle(Theme.faint)
                    }
                }
                Spacer()
                Text("\(Int(candidate.confidence * 100))%")
                    .manrope(12, .medium)
                    .foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Logic

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "Could not load image."
            return
        }
        await processImage(image)
    }

    private func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        detectedWords = []
        curatedWords = []
        selectedWords = []
        objectCandidates = []
        objectSubjectImage = nil
        objectEnglishLabel = ""
        objectForeignLabel = ""
        objectTranslations = [:]
        selectedImage = image

        defer { isProcessing = false }

        do {
            switch captureMode {
            case .text:
                let recognized = try await OCRService.recognizeText(in: image, languageCodes: [language.code, "en"])
                let tokens = tokenize(recognized)
                detectedWords = tokens
                curatedWords = await AIService.shared.curateWords(tokens, languageCode: language.code, level: language.level)
                selectedWords = Set(curatedWords)

            case .object:
                let result = try await OCRService.classifyObject(in: image)
                objectCandidates = result.candidates
                objectSubjectImage = result.subjectImage
                objectEnglishLabel = result.candidates.first?.label ?? ""
                if !result.candidates.isEmpty {
                    objectTranslationConfig = TranslationSession.Configuration(
                        source: Locale.Language(identifier: "en"),
                        target: Locale.Language(identifier: language.code)
                    )
                    objectTranslationConfig?.invalidate()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func tokenize(_ lines: [String]) -> [String] {
        let joined = lines.joined(separator: " ")
        let words = joined
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 1 }
        return Array(Set(words)).sorted()
    }

    private func prepareWordReview() {
        let manual = manualWord.trimmingCharacters(in: .whitespaces)
        if !manual.isEmpty {
            selectedWords.insert(manual)
            manualWord = ""
        }
        showWordReview = true
    }

    private func resize(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private struct WordPickerRow: View {
    let word: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(word)
                    .manrope(16, .semibold)
                    .foregroundStyle(isSelected ? Theme.ink : Theme.muted)
                Spacer()
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.green : Color.clear)
                        .frame(width: 23, height: 23)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.onGreen)
                    } else {
                        Circle()
                            .stroke(Theme.surface2, lineWidth: 1.5)
                            .frame(width: 23, height: 23)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CameraCapturePicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapturePicker

        init(_ parent: CameraCapturePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
