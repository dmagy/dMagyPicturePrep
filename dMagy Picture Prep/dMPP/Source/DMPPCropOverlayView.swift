//
//  DMPPCropOverlayView.swift
//  dMagy Picture Prep
//
//  cp-2025-11-22-VC11 — Draggable crop overlay (no handles)
//

import SwiftUI
import AppKit

/// [VC11-OVERLAY] Draws a normalized crop rect over an image
/// and lets the user drag the crop around. Aspect ratio / size
/// are now controlled by presets, +/- buttons, and the slider.
struct DMPPCropOverlayView: View {
    /// The NSImage being displayed (needed for geometry).
    let image: NSImage?

    /// The current crop rectangle in normalized coordinates (0–1).
    var rect: RectNormalized

    /// Callback when the rect changes (dragging).
    let onRectChange: (RectNormalized) -> Void

    @State private var containerSize: CGSize = .zero
    @State private var moveDragStartRect: RectNormalized?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                if let image {
                    let imageFrame = imageFrameIn(
                        containerSize: size,
                        imageSize: image.size
                    )

                    let cropFrame = cropFrameIn(
                        imageFrame: imageFrame,
                        normalizedRect: rect
                    )

                    // [VC11-DIM] Dimmed overlay with "hole" over crop.
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: size))
                        path.addRect(cropFrame)
                    }
                    .fill(
                        Color.black.opacity(0.35),
                        style: FillStyle(eoFill: true)
                    )

                    // [VC11-BOX] Crop border.
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
            .contentShape(Rectangle()) // whole overlay accepts drag for moving
            .gesture(moveDragGesture)
            .onAppear {
                containerSize = size
            }
            .onChange(of: size) { _, newSize in
                containerSize = newSize
            }
        }
    }

    // ============================================================
    // [VC11-MOVE] Drag gesture to move the entire crop
    // ============================================================

    private var moveDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard let image,
                      containerSize.width > 0,
                      containerSize.height > 0
                else { return }

                if moveDragStartRect == nil {
                    moveDragStartRect = rect
                }

                let imageFrame = imageFrameIn(
                    containerSize: containerSize,
                    imageSize: image.size
                )

                guard imageFrame.width > 0, imageFrame.height > 0 else { return }

                // Convert translation in pixels → normalized delta.
                let dxNorm = value.translation.width / imageFrame.width
                let dyNorm = value.translation.height / imageFrame.height

                var base = moveDragStartRect ?? rect
                base.x += Double(dxNorm)
                base.y += Double(dyNorm)

                // Clamp so crop stays fully inside image.
                let maxX = 1.0 - base.width
                let maxY = 1.0 - base.height

                base.x = min(max(base.x, 0.0), maxX)
                base.y = min(max(base.y, 0.0), maxY)

                onRectChange(base)
            }
            .onEnded { _ in
                moveDragStartRect = nil
            }
    }

    // ============================================================
    // [VC11-GEOM] Geometry helpers
    // ============================================================

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
