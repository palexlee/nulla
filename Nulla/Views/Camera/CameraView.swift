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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $captureMode) {
                    Text("Text / OCR").tag(CaptureMode.text)
                    Text("Object").tag(CaptureMode.object)
                }
                .pickerStyle(.segmented)
                .padding()

                if let image = selectedImage {
                    imagePreview(image)
                } else {
                    photoPickerPlaceholder
                }

                if captureMode == .text {
                    if !curatedWords.isEmpty { wordPickerList }
                    if selectedImage != nil { manualWordSection }
                } else if captureMode == .object, !objectCandidates.isEmpty {
                    objectResultView
                }

                Spacer()
            }
            .navigationTitle("Camera Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if captureMode == .text, !selectedWords.isEmpty || !manualWord.trimmingCharacters(in: .whitespaces).isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Review") { prepareWordReview() }
                    }
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
    }

    private var manualWordSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(curatedWords.isEmpty ? "Type a word to add" : "Or add a word manually")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            HStack {
                TextField("Word in \(language.displayName)", text: $manualWord)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Button {
                    let word = manualWord.trimmingCharacters(in: .whitespaces)
                    guard !word.isEmpty else { return }
                    selectedWords.insert(word)
                    if !curatedWords.contains(word) { curatedWords.append(word) }
                    manualWord = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(manualWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
        }
        .padding(.top, curatedWords.isEmpty ? 0 : 8)
    }

    private var photoPickerPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: captureMode == .text ? "doc.text.viewfinder" : "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(captureMode == .text ? "Scan text to find words" : "Identify an object")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if cameraAvailable {
                    Button {
                        showCameraCapture = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 220)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func imagePreview(_ image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if isProcessing {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.4))
                    .frame(maxHeight: 220)
                    .overlay { ProgressView().tint(.white) }
            }
        }
        .padding(.horizontal)
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
                    .padding(8)
                    .background(.regularMaterial, in: Circle())
            }
            .padding(.trailing, 24)
        }
    }

    private var wordPickerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Suggested words")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if detectedWords.count > curatedWords.count {
                    Button("Show all \(detectedWords.count)") {
                        curatedWords = detectedWords
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: 0) {
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
                        Divider().padding(.leading)
                    }
                }
            }
            .frame(maxHeight: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            if !curatedWords.isEmpty {
                Button("Select all") {
                    selectedWords = Set(curatedWords)
                }
                .font(.caption)
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }

    private var objectResultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What did you photograph?")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(objectCandidates, id: \.label) { candidate in
                    let translated = objectTranslations[candidate.label]
                    let displayLabel = translated ?? candidate.label
                    let isSelected = objectEnglishLabel == candidate.label
                    Button {
                        objectEnglishLabel = candidate.label
                        objectForeignLabel = objectTranslations[candidate.label] ?? candidate.label
                    } label: {
                        HStack {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayLabel)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if translated != nil {
                                    Text(candidate.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(Int(candidate.confidence * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 6) {
                Text("Or type it yourself")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                TextField("Word in \(language.displayName)", text: $objectForeignLabel)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .padding(.horizontal)
            }

            Button {
                showAddCardForObject = true
            } label: {
                Text(objectForeignLabel.isEmpty ? "Add to deck" : "Add \"\(objectForeignLabel)\" to deck")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(objectForeignLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal)
        }
        .padding(.top)
    }

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
            HStack {
                Text(word)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(.horizontal)
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
