//
//  DMPPCropOverlayView.swift
//  dMagy Picture Prep
//
//  cp-2025-11-22-VC8 — Draggable crop overlay for selected VirtualCrop
//

import SwiftUI
import AppKit

/// [VC8-OVERLAY] Draws a normalized crop rect over an image and
/// lets the user drag the crop around. Aspect ratio is preserved;
/// we only move the rect, not resize it (yet).
struct DMPPCropOverlayView: View {
    /// The NSImage being displayed (needed for aspect ratio).
    let image: NSImage?

    /// The current crop rectangle in normalized coordinates (0–1).
    var rect: RectNormalized

    /// Callback when the rect changes (dragging).
    let onRectChange: (RectNormalized) -> Void

    // [VC8-STATE] Keep track of container size + drag start rect.
    @State private var containerSize: CGSize = .zero
    @State private var dragStartRect: RectNormalized?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                if let image {
                    // Compute image and crop frames for current geometry.
                    let imageFrame = imageFrameIn(
                        containerSize: size,
                        imageSize: image.size
                    )

                    let cropFrame = cropFrameIn(
                        imageFrame: imageFrame,
                        normalizedRect: rect
                    )

                    // Outer dimmed overlay with a "hole" where the crop is.
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: size))
                        path.addRect(cropFrame)
                    }
                    .fill(
                        Color.black.opacity(0.35),
                        style: FillStyle(eoFill: true)
                    )

                    // The actual crop border.
                    Path { path in
                        path.addRect(cropFrame)
                    }
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .shadow(radius: 2)
                }
            }
            .contentShape(Rectangle()) // whole area is draggable
            .onAppear {
                containerSize = size
            }
            .onChange(of: size) { newSize in
                containerSize = newSize
            }
            .gesture(dragGesture)
        }
    }

    // MARK: - [VC8-GESTURE] Drag crop around

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard let image,
                      containerSize.width > 0,
                      containerSize.height > 0
                else { return }

                // Remember where we started on the first event.
                if dragStartRect == nil {
                    dragStartRect = rect
                }

                let imageFrame = imageFrameIn(
                    containerSize: containerSize,
                    imageSize: image.size
                )

                guard imageFrame.width > 0, imageFrame.height > 0 else { return }

                // Convert pixel translation → normalized delta in [0,1].
                let dxNorm = value.translation.width / imageFrame.width
                let dyNorm = value.translation.height / imageFrame.height

                var base = dragStartRect ?? rect
                base.x += Double(dxNorm)
                base.y += Double(dyNorm)

                // Clamp so crop stays entirely within the image.
                let maxX = 1.0 - base.width
                let maxY = 1.0 - base.height

                base.x = min(max(base.x, 0.0), maxX)
                base.y = min(max(base.y, 0.0), maxY)

                onRectChange(base)
            }
            .onEnded { _ in
                dragStartRect = nil
            }
    }

    // MARK: - [VC8-GEOM] Geometry helpers

    /// Compute the frame where the image is actually drawn
    /// when using `.resizable().scaledToFit()` inside `containerSize`.
    private func imageFrameIn(containerSize: CGSize, imageSize: CGSize) -> CGRect {
        let containerAspect = containerSize.width / max(containerSize.height, 1)
        let imageAspect = imageSize.width / max(imageSize.height, 1)

        let drawSize: CGSize
        let origin: CGPoint

        if imageAspect > containerAspect {
            // Image is "wider" than the container — full width, letterbox top/bottom.
            let width = containerSize.width
            let height = width / imageAspect
            drawSize = CGSize(width: width, height: height)
            origin = CGPoint(
                x: 0,
                y: (containerSize.height - height) / 2.0
            )
        } else {
            // Image is "taller" — full height, letterbox left/right.
            let height = containerSize.height
            let width = height * imageAspect
            drawSize = CGSize(width: width, height: height)
            origin = CGPoint(
                x: (containerSize.width - width) / 2.0,
                y: 0
            )
        }

        return CGRect(origin: origin, size: drawSize)
    }

    /// Convert a normalized rect (0–1) to a CGRect inside the image frame.
    private func cropFrameIn(imageFrame: CGRect, normalizedRect: RectNormalized) -> CGRect {
        let x = imageFrame.origin.x + CGFloat(normalizedRect.x) * imageFrame.size.width
        let y = imageFrame.origin.y + CGFloat(normalizedRect.y) * imageFrame.size.height
        let width = CGFloat(normalizedRect.width) * imageFrame.size.width
        let height = CGFloat(normalizedRect.height) * imageFrame.size.height

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
