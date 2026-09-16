import SwiftUI
import AVFoundation
import PhotosUI
import Combine

// MARK: - QrScannerView
struct QrScannerView: View {
    let onScan:   (String) -> Void
    let onCancel: () -> Void
    @Binding var isTorchOn: Bool

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var scanErrorMessage: String? = nil

    var body: some View {
        ZStack {
            ScannerViewController(onScan: onScan, onCancel: onCancel)
                .ignoresSafeArea()

            // Translucent Mask with Cutout
            GeometryReader { geo in
                let size = geo.size
                let boxSize: CGFloat = min(size.width * 0.72, 270)
                let rect = CGRect(
                    x: (size.width - boxSize) / 2,
                    y: (size.height - boxSize) / 2 - 20,
                    width: boxSize,
                    height: boxSize
                )

                ZStack {
                    // Dark cutout overlay
                    CutoutOverlay(cutoutRect: rect)
                        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                        .ignoresSafeArea()

                    // Corner brackets
                    CornerBracketsView(rect: rect)

                    // Helper label & Action Controls
                    VStack {
                        Spacer().frame(height: 120)

                        Spacer()

                        // Instruction pill or error
                        VStack(spacing: 8) {
                            if let err = scanErrorMessage {
                                Label(err, systemImage: "exclamationmark.circle.fill")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color.red.opacity(0.85))
                                    .clipShape(Capsule())
                                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                            } else {
                                Text("Align QR code within the frame")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 18)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                            }
                        }
                        .padding(.bottom, 20)

                        // Bottom Actions: Photos Picker
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Upload from Photos")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 22)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                        }
                        .bouncyButton(scale: 0.94)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom + 24 : 44)
                    }
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                scanErrorMessage = nil
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    if let qrString = decodeQr(from: uiImage) {
                        Haptics.success()
                        onScan(qrString)
                    } else {
                        Haptics.error()
                        scanErrorMessage = "No QR code found in selected photo"
                    }
                } else {
                    Haptics.error()
                    scanErrorMessage = "Could not load image"
                }
            }
        }
        .onChange(of: isTorchOn) { _, torch in
            toggleTorch(on: torch)
        }
        .onDisappear {
            if isTorchOn {
                toggleTorch(on: false)
            }
        }
    }

    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }

    private func decodeQr(from image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
        return features?.first?.messageString
    }
}

// MARK: - Cutout Shape
private struct CutoutOverlay: Shape {
    let cutoutRect: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(in: cutoutRect, cornerSize: CGSize(width: 18, height: 18))
        return path
    }
}

// MARK: - Corner Brackets View
private struct CornerBracketsView: View {
    let rect: CGRect
    private let len: CGFloat = 26
    private let w: CGFloat = 4
    private let strokeColor = Color(red: 0.15, green: 0.55, blue: 1.00)

    var body: some View {
        Path { path in
            // Top Left
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))

            // Top Right
            path.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))

            // Bottom Left
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - len))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + len, y: rect.maxY))

            // Bottom Right
            path.move(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        }
        .stroke(strokeColor, style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - UIViewControllerRepresentable wrapper
private struct ScannerViewController: UIViewControllerRepresentable {
    let onScan:   (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> QrScannerVC {
        let vc = QrScannerVC()
        vc.onScan   = onScan
        vc.onCancel = onCancel
        return vc
    }

    func updateUIViewController(_ uiViewController: QrScannerVC, context: Context) {}
}

// MARK: - QrScannerVC (Safe AVFoundation Controller)
final class QrScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var onScan:   ((String) -> Void)?
    var onCancel: (() -> Void)?

    private let session      = AVCaptureSession()
    private var previewLayer : AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "titan.camera.queue", qos: .userInitiated)
    private var isConfigured = false
    private var scanned      = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionAndSetup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.showDenied()
                    }
                }
            }
        default:
            showDenied()
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else { return }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ?? AVCaptureDevice.default(for: .video),
                let input  = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                DispatchQueue.main.async { self.showUnavailable() }
                return
            }

            self.session.beginConfiguration()
            self.session.addInput(input)

            let output = AVCaptureMetadataOutput()
            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                if output.availableMetadataObjectTypes.contains(.qr) {
                    output.metadataObjectTypes = [.qr]
                }
            }

            self.session.commitConfiguration()
            self.isConfigured = true

            // Safe to start running AFTER commitConfiguration
            self.session.startRunning()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let layer = AVCaptureVideoPreviewLayer(session: self.session)
                layer.frame        = self.view.bounds
                layer.videoGravity = .resizeAspectFill
                self.view.layer.insertSublayer(layer, at: 0)
                self.previewLayer  = layer
            }
        }
    }

    private func showDenied() {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 14
        container.alignment = .center
        container.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text          = "Camera access is needed to scan QR codes."
        lbl.textColor     = .white
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        lbl.font          = .systemFont(ofSize: 15, weight: .medium)

        let btn = UIButton(type: .system)
        btn.setTitle("Open Settings", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(red: 0.10, green: 0.38, blue: 0.85, alpha: 1)
        btn.layer.cornerRadius = 10
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        btn.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        container.addArrangedSubview(lbl)
        container.addArrangedSubview(btn)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func showUnavailable() {
        let lbl = UILabel()
        lbl.text          = "Camera unavailable on this device."
        lbl.textColor     = .white.withAlphaComponent(0.7)
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        lbl.font          = .systemFont(ofSize: 14)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lbl)

        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            lbl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            lbl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            !scanned,
            let obj   = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            obj.type == .qr,
            let value = obj.stringValue,
            !value.isEmpty
        else { return }

        scanned = true
        Haptics.medium()
        sessionQueue.async { [weak self] in self?.session.stopRunning() }
        onScan?(value)
    }
}
