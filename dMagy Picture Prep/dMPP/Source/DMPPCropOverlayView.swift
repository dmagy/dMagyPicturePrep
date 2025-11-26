//
//  DMPPCropOverlayView.swift
//  dMagy Picture Prep
//
//  cp-2025-11-22-VC11 — Draggable crop overlay (no handles)
//

import SwiftUI
import AppKit

// MARK: - Image + Crop Overlay

/// [DMPP-SI-PREVIEW] Real image preview with a crop overlay (non-interactive for now).
struct DMPPCropOverlayView: View {

    let image: NSImage
    let rect: RectNormalized
    let isHeadshot: Bool
    let onRectChange: (RectNormalized) -> Void

    @State private var dragStartRect: RectNormalized?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // [OVL-IMG] The image is already drawn by the parent ZStack in DMPPCropEditorPane.
                // This overlay just draws crop + extras and handles gestures.

                // --- Compute image & crop frames in view space ---
                let imageSize = image.size
                let container = geo.frame(in: .local)

                // Fit the image into the container, preserving aspect ratio
                let imageRect = fitImageRect(imageSize: imageSize, in: container)

                // Convert normalized crop rect (0–1) into image-space rect
                let cropFrame = CGRect(
                    x: imageRect.minX + CGFloat(rect.x) * imageRect.width,
                    y: imageRect.minY + CGFloat(rect.y) * imageRect.height,
                    width: CGFloat(rect.width) * imageRect.width,
                    height: CGFloat(rect.height) * imageRect.height
                )

                // --- Main dashed crop border ---
                Path { path in
                    path.addRect(cropFrame)
                }
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundStyle(Color.white)

                // --- Headshot crosshairs (only for headshot crops) ---
                if isHeadshot {
                    Path { path in
                        // Treat crop as an 8×10 grid.
                        // Vertical crosshairs at X = 2 and 6 (of 8 width)
                        // Horizontal crosshairs at Y = 1 and 7 (of 10 height)

                        let colWidth  = cropFrame.width / 8.0
                        let rowHeight = cropFrame.height / 10.0

                        // Vertical line at 2/8
                        let v2x = cropFrame.minX + 2.0 * colWidth
                        path.move(to: CGPoint(x: v2x, y: cropFrame.minY))
                        path.addLine(to: CGPoint(x: v2x, y: cropFrame.maxY))

                        // Vertical line at 6/8
                        let v6x = cropFrame.minX + 6.0 * colWidth
                        path.move(to: CGPoint(x: v6x, y: cropFrame.minY))
                        path.addLine(to: CGPoint(x: v6x, y: cropFrame.maxY))

                        // Horizontal line at 1/10
                        let h1y = cropFrame.minY + 1.0 * rowHeight
                        path.move(to: CGPoint(x: cropFrame.minX, y: h1y))
                        path.addLine(to: CGPoint(x: cropFrame.maxX, y: h1y))

                        // Horizontal line at 7/10
                        let h7y = cropFrame.minY + 7.0 * rowHeight
                        path.move(to: CGPoint(x: cropFrame.minX, y: h7y))
                        path.addLine(to: CGPoint(x: cropFrame.maxX, y: h7y))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.white.opacity(0.9))
                }


            }
            // You still have drag / gesture handling here; preserving it:
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let imageSize = image.size
                        let container = geo.frame(in: .local)
                        let imageRect = fitImageRect(imageSize: imageSize, in: container)

                        if dragStartRect == nil {
                            dragStartRect = rect
                        }

                        guard let startRect = dragStartRect else { return }

                        let dx = Double(value.translation.width / imageRect.width)
                        let dy = Double(value.translation.height / imageRect.height)

                        var newRect = startRect
                        newRect.x = min(max(0.0, startRect.x + dx), 1.0 - startRect.width)
                        newRect.y = min(max(0.0, startRect.y + dy), 1.0 - startRect.height)

                        onRectChange(newRect)
                    }
                    .onEnded { _ in
                        dragStartRect = nil
                    }
            )
        }
        .allowsHitTesting(true)
    }

    // MARK: - Helpers

    /// Compute the rectangle in which the image is drawn (aspect-fit inside container).
    private func fitImageRect(imageSize: CGSize, in container: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return container }

        let imageAR = imageSize.width / imageSize.height
        let containerAR = container.width / max(container.height, 1)

        if imageAR > containerAR {
            // Image is "wider": full width, center vertically
            let width = container.width
            let height = width / imageAR
            let y = container.minY + (container.height - height) / 2.0
            return CGRect(x: container.minX, y: y, width: width, height: height)
        } else {
            // Image is "taller": full height, center horizontally
            let height = container.height
            let width = height * imageAR
            let x = container.minX + (container.width - width) / 2.0
            return CGRect(x: x, y: container.minY, width: width, height: height)
        }
    }
}


