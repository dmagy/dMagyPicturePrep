//
//  DMPPCropOverlayView.swift
//  dMagy Picture Prep
//
//  cp-2025-11-22-VC11+TINT — Draggable crop overlay with outside tint + optional headshot guides
//

import SwiftUI
import AppKit

// MARK: - Image + Crop Overlay

/// Draws the crop overlay on top of the image:
/// - darkens outside the crop
/// - shows a dashed border
/// - draws headshot guides when needed (variant-aware)
/// - supports drag-to-move for all crops
/// - supports a bottom-right resize handle for freeform crops.
struct DMPPCropOverlayView: View {

    let image: NSImage
    let rect: RectNormalized

    /// Whether this crop should show headshot guides at all.
    let isHeadshot: Bool

    /// Which headshot template to draw (only used when isHeadshot == true).
    /// If nil, defaults to Tight template for backward compatibility.
    let headshotVariant: VirtualCrop.HeadshotVariant?

    let isFreeform: Bool
    let onRectChange: (RectNormalized) -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Template Config (Phase 3)

    /// Headshot guide positions expressed as fractions of crop width/height.
    /// For an 8×10 crop, these are “gridline” ratios, not pixels.
    private struct HeadshotTemplate {
        let v1: Double  // first vertical line as fraction of width
        let v2: Double  // second vertical line as fraction of width
        let h1: Double  // first horizontal line as fraction of height
        let h2: Double  // second horizontal line as fraction of height
    }

 
    private static let tightTemplate = HeadshotTemplate(
        v1: 2.0 / 8.0,
        v2: 6.0 / 8.0,
        h1: 1.0 / 10.0,
        h2: 7.0 / 10.0
    )

    private static let fullTemplate = HeadshotTemplate(
        v1: 2.5 / 8.0,
        v2: 5.5 / 8.0,
        // Lower both horizontals a bit vs Tight (tune freely)
        h1: 1.0 / 10.0,
        h2: 5.5 / 10.0
    )

    private func template(for variant: VirtualCrop.HeadshotVariant?) -> HeadshotTemplate {
        switch variant ?? .tight {
        case .tight: return Self.tightTemplate
        case .full:  return Self.fullTemplate
        }
    }

    // MARK: - Tuning knobs

    private var overlayColor: Color { .black }

    private var overlayOpacity: Double {
        switch colorScheme {
        case .light: return 0.45
        case .dark:  return 0.60
        @unknown default: return 0.50
        }
    }

    @State private var dragStartRect: RectNormalized?
    @State private var resizeStartRect: RectNormalized?
    @State private var resizeStartLocation: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let container = geo.frame(in: .local)
            let imageRect = fitImageRect(imageSize: image.size, in: container)

            let cropFrame = CGRect(
                x: imageRect.minX + CGFloat(rect.x) * imageRect.width,
                y: imageRect.minY + CGFloat(rect.y) * imageRect.height,
                width: CGFloat(rect.width) * imageRect.width,
                height: CGFloat(rect.height) * imageRect.height
            )

            ZStack {
                // 1) Dim everything *inside the image* except the crop.
                Path { path in
                    path.addRect(imageRect)
                    path.addRect(cropFrame)
                }
                .fill(
                    overlayColor.opacity(overlayOpacity),
                    style: FillStyle(eoFill: true) // even-odd: "hole" where crop is
                )

                // 2) Dashed crop border.
                Path { path in
                    path.addRect(cropFrame)
                }
                .stroke(
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .foregroundStyle(.white)

                // 3) Headshot guides (variant-aware)
                if isHeadshot {
                    let dashStyle = StrokeStyle(lineWidth: 1, dash: [4, 3])
                    let t = template(for: headshotVariant)

                    let v1 = cropFrame.minX + cropFrame.width  * t.v1
                    let v2 = cropFrame.minX + cropFrame.width  * t.v2
                    let h1 = cropFrame.minY + cropFrame.height * t.h1
                    let h2 = cropFrame.minY + cropFrame.height * t.h2

                    // Vertical 1
                    Path { p in
                        p.move(to: CGPoint(x: v1, y: cropFrame.minY))
                        p.addLine(to: CGPoint(x: v1, y: cropFrame.maxY))
                    }
                    .stroke(Color.white.opacity(0.9), style: dashStyle)

                    // Vertical 2
                    Path { p in
                        p.move(to: CGPoint(x: v2, y: cropFrame.minY))
                        p.addLine(to: CGPoint(x: v2, y: cropFrame.maxY))
                    }
                    .stroke(Color.white.opacity(0.9), style: dashStyle)

                    // Horizontal 1
                    Path { p in
                        p.move(to: CGPoint(x: cropFrame.minX, y: h1))
                        p.addLine(to: CGPoint(x: cropFrame.maxX, y: h1))
                    }
                    .stroke(Color.white.opacity(0.9), style: dashStyle)

                    // Horizontal 2
                    Path { p in
                        p.move(to: CGPoint(x: cropFrame.minX, y: h2))
                        p.addLine(to: CGPoint(x: cropFrame.maxX, y: h2))
                    }
                    .stroke(Color.white.opacity(0.9), style: dashStyle)
                }

                // 4) Freeform resize handle in the bottom-right corner.
                if isFreeform {
                    let handleSize: CGFloat = 14
                    let handleRect = CGRect(
                        x: cropFrame.maxX - handleSize,
                        y: cropFrame.maxY - handleSize,
                        width: handleSize,
                        height: handleSize
                    )

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.black.opacity(0.6))
                        )
                        .frame(width: handleRect.width, height: handleRect.height)
                        .position(x: handleRect.midX, y: handleRect.midY)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if resizeStartRect == nil || resizeStartLocation == nil {
                                        resizeStartRect = rect
                                        resizeStartLocation = value.startLocation
                                    }
                                    guard let startRect = resizeStartRect,
                                          let startLocation = resizeStartLocation
                                    else { return }

                                    // Convert drag delta from points → normalized
                                    let dxNorm = Double((value.location.x - startLocation.x) / imageRect.width)
                                    let dyNorm = Double((value.location.y - startLocation.y) / imageRect.height)

                                    var newRect = startRect
                                    newRect.width = max(0.01, min(1.0 - newRect.x, startRect.width + dxNorm))
                                    newRect.height = max(0.01, min(1.0 - newRect.y, startRect.height + dyNorm))

                                    onRectChange(newRect)
                                }
                                .onEnded { _ in
                                    resizeStartRect = nil
                                    resizeStartLocation = nil
                                }
                        )
                }
            }
            // 5) Dragging the whole crop.
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartRect == nil {
                            dragStartRect = rect
                        }
                        guard let startRect = dragStartRect else { return }

                        let dx = Double(value.translation.width  / imageRect.width)
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
