import SwiftUI
import SDWebImageSwiftUI

struct DevTempView: View {
    let urlString: String = "https://flymarshall.com/co-4k/OUT/FCST/sounding1.curr.1600lst.d2.png?1753456649"

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            WebImage(url: URL(string: urlString)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Text("Tap to view")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    // Zoom
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = max(1.0, newScale)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            offset = clampedOffset(
                                offset,
                                in: geometry.size,
                                scale: scale
                            )
                            lastOffset = offset
                        },

                    // Pan
                    DragGesture()
                        .onChanged { value in
                            let newOffset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                            offset = clampedOffset(newOffset, in: geometry.size, scale: scale)
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
            )
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black.opacity(0.01))
        }
    }

    // Clamp offset so no part of image moves inside screen
    private func clampedOffset(_ offset: CGSize, in containerSize: CGSize, scale: CGFloat) -> CGSize {
        // The image is fit-aspect, so its dimensions depend on container
        let imageAspectRatio: CGFloat = 1.0 // 1:1 is safe for weather plots; override if needed

        let imageSize: CGSize
        if containerSize.width / containerSize.height < imageAspectRatio {
            // width-bound
            let width = containerSize.width * scale
            let height = width / imageAspectRatio
            imageSize = CGSize(width: width, height: height)
        } else {
            // height-bound
            let height = containerSize.height * scale
            let width = height * imageAspectRatio
            imageSize = CGSize(width: width, height: height)
        }

        let horizontalLimit = max(0, (imageSize.width - containerSize.width) / 2)
        let verticalLimit = max(0, (imageSize.height - containerSize.height) / 2)

        return CGSize(
            width: offset.width.clamped(to: -horizontalLimit...horizontalLimit),
            height: offset.height.clamped(to: -verticalLimit...verticalLimit)
        )
    }
}

// Helper to clamp CGFloat values
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
