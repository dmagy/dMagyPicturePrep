# Saving Your Work

dMPP saves your work as metadata beside each picture.

Your original picture file is not changed.

## How saving works

When you save a picture, dMPP writes or updates a sidecar file next to the original image.

Example:

```text
IMG_2042.jpg
IMG_2042.dmpms.json
```

The `.dmpms.json` file stores the information dMPP knows about the picture.

## What gets saved

A sidecar may include:

- Title
- Description
- Private Notes
- Date Taken or Era
- People
- Location
- Tags
- Virtual crops
- Face review information
- Other dMPP metadata

The sidecar describes the picture. It does not replace or modify the picture.

## Next Picture saves automatically

The normal workflow is:

```text
Review picture → Click Next Picture → dMPP saves and moves forward
```

When you click **Next Picture**, dMPP saves the current picture’s changes before moving to the next picture.

This lets you review pictures in a steady rhythm without manually saving every time.

## Manual Save

You can also click **Save** when you want to write the current picture’s changes before doing something else.

Use **Save** when:

- you are about to close the app
- you are switching folders
- you want to make sure recent changes are written
- you are pausing in the middle of review

If there are no unsaved changes, the Save button may appear inactive or dimmed.

## Original pictures are safe

dMPP does not edit the original picture file during normal review.

For example:

- changing a title does not rename the picture file
- changing a crop does not crop the picture file
- adding people does not write into the image file
- adding a location does not alter the original photo metadata

dMPP saves your work beside the picture instead.

## Virtual crops

Crops in dMPP are virtual.

A virtual crop stores instructions for how the picture should be framed.

For example, one picture might have:

- Original
- Landscape 16:9
- Portrait 4:5
- Headshot crop

The original image remains unchanged.

When you export a crop, dMPP creates a separate image file from the selected crop.

## Save and Suggested mode

Suggested mode may require all visible detected faces to be assigned or ignored before saving or moving to another picture.

This helps prevent unreviewed detected faces from being accidentally skipped.

If dMPP prevents saving or moving forward, review the face chips and either:

- assign each visible face to a person
- mark it as a one-off
- ignore the face when appropriate

## Save failures

Saving can fail if dMPP cannot write the sidecar or cannot access portable archive data.

Possible causes include:

- macOS folder permission expired
- Dropbox, iCloud Drive, or another cloud service is syncing or blocking access
- the picture folder was moved or renamed
- the folder is read-only
- the disk is full
- the current Picture Library Folder needs to be refreshed

If saving fails or data seems missing, try **Change or Refresh Picture Library Folder…** and select the same Picture Library Folder again.

## What to back up

To preserve your dMPP work, back up all of these:

- your original picture files
- `.dmpms.json` sidecar files
- the `dMagy Portable Archive Data` folder

These pieces work together.

## If you move your archive

If you move your picture archive to another drive or computer, keep these together:

```text
Your picture folders
.dmpms.json sidecar files
dMagy Portable Archive Data
```

After moving the archive, use **Change or Refresh Picture Library Folder…** and select the moved Picture Library Folder.

## Good habit

When reviewing pictures, use **Next Picture** as part of your rhythm.

That keeps saving simple:

```text
Review → Next Picture → saved
```

Use manual **Save** when you want extra confidence before pausing, closing, or changing folders.
