# Sidecars and Portable Archive Data

dMPP saves your work without changing your original picture files.

It does this with two related pieces:

- a sidecar file beside each picture
- a shared portable archive data folder inside your Picture Library Folder

## What is a sidecar file?

A sidecar file is a separate file stored beside a picture.

Example:

```text
IMG_2042.jpg
IMG_2042.dmpms.json
```

The picture remains unchanged. The sidecar stores the information dMPP adds about the picture.

## What sidecars can store

A dMPP sidecar may include:

- Title
- Description
- Private Notes
- Date Taken or Era
- People in the picture
- Location
- Tags
- Virtual crops
- Face review information
- Other dMPP metadata

The sidecar is plain JSON, which is a readable text-based data format.

You do not need to understand JSON to use dMPP.

## Why dMPP uses sidecars

Sidecars help keep your archive portable.

They allow dMPP to save useful information about a picture without editing the image itself.

This means:

- your original picture stays clean
- your metadata can travel with the picture
- other dMagy tools can read the same information later
- the archive remains more understandable over time

## What is dMPMS?

dMPMS means:

```text
dMagy Photo Metadata Standard
```

It is the sidecar format dMPP uses to describe pictures.

A `.dmpms.json` file is a dMPMS sidecar.

## What is Portable Archive Data?

Inside your Picture Library Folder, dMPP creates or uses:

```text
dMagy Portable Archive Data
```

This folder stores shared information used across the archive.

Examples include:

- People registry
- Locations registry
- Tags registry
- Crop presets
- Face recognition index data
- Supporting metadata and indexes

The sidecar describes one picture. The portable archive data folder stores shared definitions used by many pictures.

## Example

Picture:

```text
Family Photos / 1998 / IMG_1048.jpg
```

Sidecar:

```text
Family Photos / 1998 / IMG_1048.dmpms.json
```

Shared archive data:

```text
Family Photos / dMagy Portable Archive Data /
```

The sidecar may say the picture includes a person. The People registry inside `dMagy Portable Archive Data` stores the reusable information about that person.

## Do not delete portable archive data casually

Most users do not need to manage `dMagy Portable Archive Data` by hand.

Do not delete it unless you intentionally want to remove dMPP’s shared archive data for that Picture Library Folder.

If this folder is missing or inaccessible, dMPP may appear to have lost People, Locations, Tags, Crops, or learned face data.

## Backing up your archive

To preserve your dMPP work, back up all of these:

- your original picture files
- `.dmpms.json` sidecar files
- the `dMagy Portable Archive Data` folder

## Shared archives and multiple users

A Picture Library Folder can be stored in a shared folder service such as Dropbox, as long as each user has access to the same folder structure.

This allows more than one person to work with the same photo archive and the same `dMagy Portable Archive Data` folder.

dMPP is designed to help reduce collisions when multiple people use the same archive. For example, dMPP can warn when another user appears to be working with the same picture or shared Settings area.

This protection is helpful, but it is not the same as a full database server or real-time collaboration system. Avoid having multiple people edit the same picture or the same Settings section at the same time.

Good shared-library habits:

- Coordinate with each other and work in different sections of your collection
- Let Dropbox or your sync service finish syncing before another person starts.
- Avoid editing the same picture at the same time.
- Avoid changing People, Locations, Tags, or Crops in Settings at the same time as another person.
- If dMPP warns about another user or possible lock, pause and coordinate before continuing.

These pieces work together.

## Private Notes

Private Notes are stored in the sidecar file.

They are intended for curator notes, uncertainty, repair clues, and follow-up tasks. They are not intended for display in slideshows or public family views.

Private Notes are not encrypted or hidden. They are stored plainly in the sidecar file.

## Original pictures are not changed

dMPP does not crop, rename, rewrite, or alter your original picture file as part of normal editing.

Crops are virtual. Metadata is written separately. Your original image remains intact.
