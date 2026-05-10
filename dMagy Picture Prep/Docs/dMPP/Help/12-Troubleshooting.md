# Troubleshooting

This topic covers common issues and what to try first.

## My People, Locations, Tags, or Crops seem missing

This usually means dMPP is not using the Picture Library Folder you expected, or macOS is not currently allowing access to the portable archive data.

Try this first:

1. Choose **Change or Refresh Picture Library Folder…**
2. Select the same top-level Picture Library Folder again.
3. Reopen Settings and check People, Locations, Tags, and Crops.

Reselecting the folder can refresh macOS permission, especially when the archive is in Dropbox, iCloud Drive, or another cloud-backed folder.

## Settings says it cannot open or mentions another editor

If Settings cannot open, the real problem may be folder access rather than another person editing Settings.

Try this first:

1. Quit dMPP.
2. Reopen dMPP.
3. Use **Change or Refresh Picture Library Folder…**
4. Select the same Picture Library Folder again.

If the issue continues, check whether the folder is inside cloud storage and whether it is available locally.

## dMPP cannot save

Saving may fail if dMPP cannot write beside the current picture or inside the portable archive data folder.

Possible causes include:

- macOS folder permission expired
- cloud storage is syncing or blocking access
- the folder was moved or renamed
- the file is on read-only media
- the disk is full
- the picture folder does not allow new files

Try this first:

1. Reselect the Picture Library Folder.
2. Confirm the picture folder is writable in Finder.
3. Check whether cloud storage has finished syncing.
4. Try saving again.

## I see `.dmpms.json` files beside my pictures

That is expected.

Those are dMPP sidecar files. They store the information you add about each picture.

Example:

```text
IMG_2042.jpg
IMG_2042.dmpms.json
```

The original picture is not changed.

## I chose the wrong Picture Library Folder

Use **Change or Refresh Picture Library Folder…** and choose the correct top-level folder.

If the newly selected folder does not contain `dMagy Portable Archive Data`, dMPP will warn before creating a new empty archive data folder.

If you expected your saved People, Locations, Tags, or Crops to appear, choose the folder that already contains your existing `dMagy Portable Archive Data`.

## My pictures are in Apple Photos

dMPP does not work directly inside the Apple Photos library.

Export the pictures from Apple Photos to regular folders first. Then choose the exported folder structure as your Picture Library Folder.

## Suggested mode found no faces

This can happen when:

- faces are too small
- faces are turned away
- the photo is blurry
- the photo is a landscape or object photo
- the image does not contain clear human faces

Use Manual mode when Suggested mode is not a good fit.

## Suggested mode suggested the wrong person

Suggestions are only suggestions. Review each one before moving on.

If dMPP suggests the wrong person, choose the correct person instead.

If dMPP warns that a very strong match differs from your assignment, the suggested person’s learned face samples may include a bad example. You may want to review or clear learned samples for that person in Settings > People.

## A deleted person is still being suggested

This can happen if dMPP learned face samples for a person who was later deleted from Settings > People.

When this happens, dMPP may show a warning that learned face samples exist for a deleted person.

Use **Remove Learned Samples** in that warning to stop the deleted person from being suggested.

## I do not know who someone is

Use an unknown person label.

Examples:

```text
Unknown woman
Unknown child
Unknown man near truck
Unknown cousin?
```

A useful unknown label is better than leaving the person unmarked, especially in group photos.

## GPS gave the wrong address

GPS and reverse geocoding are not always exact. A photo taken at one house may resolve to a nearby address.

If you have a saved Location that matches the real place, use the saved Location.

You can also manually correct the address fields.

## The face boxes are hidden on a headshot crop

That is intentional.

Face boxes are temporarily hidden while viewing or editing headshot crops so the crop view is easier to see. Your normal face-box setting returns when you switch to another crop.

## I deleted a crop. Did that delete my picture?

No.

Deleting a crop removes that virtual crop from the picture metadata. It does not delete or edit the original image.

## I am not sure what to back up

Back up all of these:

- your picture files
- `.dmpms.json` sidecar files
- the `dMagy Portable Archive Data` folder

Together, these preserve your dMPP archive work.

## When in doubt

If something seems wrong, do not delete files first.

Start by refreshing access to the Picture Library Folder or checking whether you selected the expected archive root.

## Another person may be using the same archive

If your Picture Library Folder is in Dropbox or another shared folder service, another person may be using the same archive.

dMPP may show warnings to help prevent two users from editing the same picture or shared Settings data at the same time.

If you see a warning about another user or a lock:

1. Pause before saving or changing Settings.
2. Check whether someone else has the archive open.
3. Let your sync service finish syncing.
4. Continue when you are confident no one else is editing the same picture or Settings area.

If you are sure no one else is using the archive, refreshing access to the Picture Library Folder may help.
