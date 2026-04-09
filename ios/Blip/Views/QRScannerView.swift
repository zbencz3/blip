import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        vc.onCancel = { dismiss() }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    nonisolated(unsafe) var onScan: ((String) -> Void)?
    nonisolated(unsafe) var onCancel: (() -> Void)?
    private var captureSession: AVCaptureSession?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupOverlay()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showError("Camera not available")
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func setupOverlay() {
        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        // Instructions label
        let label = UILabel()
        label.text = "Scan the QR code from your other device"
        label.textColor = .white
        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        // Viewfinder frame
        let frame = UIView()
        frame.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        frame.layer.borderWidth = 2
        frame.layer.cornerRadius = 16
        frame.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frame)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            frame.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frame.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frame.widthAnchor.constraint(equalToConstant: 240),
            frame.heightAnchor.constraint(equalToConstant: 240),
        ])
    }

    @objc private func closeTapped() {
        captureSession?.stopRunning()
        onCancel?()
    }

    private func showError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = metadata.stringValue,
              value.hasPrefix("bps_usr_") else { return }

        hasScanned = true
        captureSession?.stopRunning()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        onScan?(value)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}
