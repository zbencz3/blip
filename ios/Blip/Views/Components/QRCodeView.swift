import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let url: String
    let size: CGFloat

    init(url: String, size: CGFloat = 200) {
        self.url = url
        self.size = size
    }

    var body: some View {
        if let image = generateQRCode(from: url) {
            Image(image, scale: 1, label: Text("QR Code"))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: size * 0.5))
                .foregroundStyle(BlipColors.textSecondary)
                .frame(width: size, height: size)
        }
    }

    private func generateQRCode(from string: String) -> CGImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return context.createCGImage(scaledImage, from: scaledImage.extent)
    }
}
