# Crops

Crops in dMPP define useful views of a picture without changing the original image.

A crop tells dMPP how the picture should be framed for a particular purpose, such as a slideshow, print, display, grid, or person-focused view.

## Why Crops matter

A single picture can be useful in more than one shape.

For example, one scanned photo might need:

- the full original image
- a landscape crop for a TV slideshow
- a portrait crop for printing
- a square crop for a grid
- a headshot crop for a person-focused view

dMPP stores these as virtual crops. The original picture remains unchanged.

## Virtual crops

Crops in dMPP are virtual.

That means dMPP stores crop instructions as metadata. It does not crop or overwrite the original image file.

For example:

```text
IMG_2042.jpg
IMG_2042.dmpms.json
```

The picture file stays the same. The sidecar file stores the crop information.

## Common crop types

Common crops may include:

- Original
- Landscape 16:9
- Portrait 4:5
- Square 1:1
- Headshot (Full)
- Headshot (Tight)
- Custom crops

The available crop choices may depend on your crop settings and the crops already saved for the current picture.

## Default crops

dMPP will create default crops for new pictures.

For example, you may choose to have new pictures start with:

- Landscape 16:9
- Portrait 4:5

Default crops give you a useful starting point without requiring you to add crops one at a time for every picture.

You can adjust default crop behavior in Settings > Crops.

## Selecting a crop

Crop chips appear above the image area.

Click a crop chip to select that crop.

When a crop is selected, the image area shows the crop overlay so you can adjust the framing.

## Adjusting a crop

You can adjust a crop by:

- dragging the crop box to reposition it
- using the crop controls to change size
- switching between crop chips to compare different views

The crop remains editable. You can come back and adjust it later.

## New Crop

Use **New Crop** when the current picture needs another crop.

Examples:

- a square version for a grid
- a tighter portrait crop
- a headshot crop
- a custom crop shape

Only add crops that will be useful later. Not every picture needs every crop type.

## Crop Actions

Use the **Actions** menu near **New Crop** for actions on the selected crop.

Actions may include:

- Export Selected Crop
- Export Selected Crop To…
- Delete Selected Crop

You can also right-click a crop chip for quick actions on that specific crop.

## Exporting a crop

Exporting a crop creates a separate image file from the selected crop.

This does not change the original picture.

Use export when you want an actual image file for:

- sharing
- printing
- uploading
- testing a crop outside dMPP
- using a prepared image somewhere else

## Export vs. crop metadata

A virtual crop is saved as metadata.

An exported crop is a new image file.

Use the virtual crop when you are preparing the archive. Use export when you need a separate finished image file.

## Deleting a crop

Deleting a crop removes that virtual crop from the current picture.

It does not delete the original image.

It also does not delete other crops for the same picture.

Use delete when a crop does not work for that picture or is no longer needed.

## Headshot crops

Headshot crops are intended for person-focused views.

A picture may have a headshot crop for a specific person, such as:

- Headshot (Full)
- Headshot (Tight)

Headshot crops are useful for future people-focused displays, family history views, or tools that need a consistent view of a person.

When adjusting a headshot crop, use the crosshairs as a guide for the person’s head. Align the top, bottom, and sides of the crosshair guide with the top, bottom, and sides of the head as closely as makes sense for the picture.

The goal is not mathematical perfection. The goal is a consistent, useful starting point for person-focused display.

While viewing or editing a headshot crop, dMPP temporarily hides face boxes so the crop view is less crowded.

## Original crop

An Original crop represents the full image.

Use it when the whole picture matters or when you want to preserve the full frame as one of the available views.

## Custom crop presets

Custom crop presets let you define crop shapes that are useful for your own workflow.

Examples might include:

- a frame size you often print
- a display ratio used by a specific screen
- a custom layout for a project

Use Settings > Crops to manage crop presets.

## Good habits

Start with the default crops and adjust only what matters.

Add extra crops when there is a clear reason.

Use headshot crops when a person-focused view will be useful later.

Delete crops that do not work for the picture so the crop list stays meaningful.

## Original pictures are safe

Adjusting, adding, deleting, or exporting crops does not modify the original picture file.

dMPP stores crop instructions in metadata and creates a separate file only when you export a crop.
