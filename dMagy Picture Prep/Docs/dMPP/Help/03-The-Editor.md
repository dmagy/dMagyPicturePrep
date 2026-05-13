# The Editor

The editor is where you review and prepare one picture at a time.

It is arranged around two main jobs:

- the image area, where you view the picture and adjust crops
- the metadata area, where you describe the picture

The goal is not to change the original picture. The goal is to add useful information beside the picture so the archive becomes easier to review, search, preserve, and display later.

## Basic editor workflow

A typical review session looks like this:

1. Choose a working folder.
2. Review the current picture.
3. Add or confirm the title, description, date, people, location, tags, and crops.
4. Click **Next Picture**.
5. dMPP saves the current picture’s metadata and moves forward.

You do not need to fill in every field for every picture. Use the information you have.

## Working folder

The working folder is the folder of pictures you are reviewing right now.

It should usually be inside your Picture Library Folder.

For example:

```text
Picture Library Folder:
Family Photos

Working folder:
Family Photos / 1984 / Christmas
```

The Picture Library Folder controls the shared archive data. The working folder controls which pictures you are reviewing now.

## Review options

The review option controls which pictures dMPP shows from the selected working folder.

### All Pictures

Shows all supported pictures in the selected folder.

Use this when you want to review everything or when you are not sure where to start.

### Never Reviewed

Shows pictures that do not yet have dMPP sidecar metadata.

Use this when you want to focus on pictures you have not worked on before.

### Flagged

Shows pictures marked with the reserved **Flagged** tag.

Use this for follow-up work, uncertain dates, missing details, or pictures you want to revisit later.

## Image area

The image area shows the current picture and its crop overlay.

You can use it to:

- view the picture
- select a crop
- adjust crop position
- adjust crop size
- show or hide face boxes
- reveal the current picture in Finder

Crops are virtual. Adjusting a crop does not edit the original image file.

## Crop chips

Crop chips appear above the image area.

Use them to switch between the crops saved for the current picture.

Common crop types include:

- Original
- Landscape 16:9
- Portrait 4:5
- Square
- Headshot crops

Right-click a crop chip for quick crop actions such as export or delete.

You can also use the **Actions** menu near **New Crop** for selected crop actions.

## Face boxes

When Suggested mode is active, dMPP may show face boxes over the image.

Face boxes help you see which detected face matches each numbered face slot.

You can show or hide face boxes from the editor. Face boxes are temporarily hidden while viewing or editing headshot crops so the crop is easier to see.

## Metadata area

The metadata area is where you describe the picture.

It includes sections such as:

- Title and Description
- Curator Notes
- Date Taken or Era
- Tags
- People
- Location

These fields help preserve the meaning of the picture, not just the pixels.

## Title and Description

Use the title for a short, useful name for the picture.

Use the description for the story or context of this specific picture.

Unlike file names, picture titles do not need to be unique.

Example:

```text
Title:
Christmas morning

Description:
Anna, Zach, and Hannah opening presents at Grandma Jean’s house.
```

## Curator Notes

Curator Notes are for curator-facing notes, uncertainty, repair clues, and follow-up tasks.

Examples:

```text
Ask Mom who the person in the back row is.
Date may be 1984, not 1985.
Need better crop before using in slideshow.
```

Curator Notes are not intended for display, but they are stored plainly in the sidecar file. They are not encrypted or hidden.

## Date Taken or Era

Use the best date or era you know.

An exact date is helpful, but an approximate date is still useful.

Examples:

```text
1984-07-04
1984-07
1984
1980s
1978-1982
1984-06 to 1984-08
```

Dates help with sorting, searching, and age clues for people.

## People

Use People to identify who appears in the picture.

dMPP has two People modes:

- **Suggested**, which detects faces and may suggest people based on learned examples
- **Manual**, which lets you identify people yourself, row by row when helpful

Suggested mode is useful for clear face-forward photos. Manual mode is useful for group photos, unclear faces, pets, statues, or photos where face detection is not enough.

## Location

Use Location to record where the picture was taken or what place it represents.

You can use:

- a saved Location
- GPS-derived information from the picture
- manually entered location details

Saved Locations help keep place names consistent across the archive.

## Tags

Tags are reusable labels that help categorize and filter pictures.

Use tags for broad, useful categories such as:

- Christmas
- Wedding
- School
- Military
- Do Not Display
- Flagged

Use the description field for the story of a specific picture.

## Navigation

Use **Previous Picture** and **Next Picture** to move through the working folder.

The usual workflow is to click **Next Picture** when you are done reviewing the current picture. dMPP saves the current picture before moving forward.

If Suggested mode has visible faces that are not assigned or ignored, dMPP may prevent you from moving forward until those faces are handled.

## Revealing the current picture in Finder

Clicking the current file name in the editor reveals the picture in Finder.

This is useful when you want to confirm the file’s location, inspect nearby files, or manage the folder outside dMPP.

## Original pictures are not changed

The editor may feel like an image editor, but dMPP does not alter the original picture file during normal use.

Your work is stored as metadata:

- in a sidecar file beside the picture
- in shared portable archive data inside the Picture Library Folder

The original image remains intact.
