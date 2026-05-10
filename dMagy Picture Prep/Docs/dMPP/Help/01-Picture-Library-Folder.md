# Picture Library Folder

The Picture Library Folder is the top-level folder dMPP uses as the home for your photo archive.

It should be the folder that contains all the pictures you want to prepare, either directly or inside subfolders.

## Why this folder matters

dMPP is designed around one archive root.

Inside your Picture Library Folder, dMPP creates or uses a folder named:

```text
dMagy Portable Archive Data
```

This folder stores shared archive information, including:

- People
- Locations
- Tags
- Crops
- Face recognition index data
- Other portable dMPP support files

This shared data belongs with your archive, not just with one computer.

## Example folder structure

```text
Family Photos/
  1970s/
  1980s/
  Christmas/
  Reunions/
  Scanned Albums/
  dMagy Portable Archive Data/
```

In this example, `Family Photos` should be the Picture Library Folder.

You can review pictures in any subfolder, but the same People, Locations, Tags, and Crops remain available throughout the archive.

## Choosing the right folder

Choose the folder that contains the picture collection you want dMPP to treat as one archive.

Good choices include:

- `Family Photos`
- `Photo Archive`
- `Scanned Pictures`
- `Pictures to Organize`

Less ideal choices include:

- one small event folder, such as `Christmas 1998`
- `Downloads`
- `Desktop`
- a temporary scan batch
- a folder you plan to move or delete soon

A small event folder may work for testing, but it can create confusion later if you choose another folder and wonder why your People, Locations, Tags, or Crops are missing.

## Picture Library Folder vs. working folder

These are related, but they are not the same.

### Picture Library Folder

The Picture Library Folder is the root of the archive.

It controls where dMPP stores shared archive data.

### Working folder

The working folder is the folder you are reviewing right now.

For example:

```text
Picture Library Folder:
Family Photos

Working folder:
Family Photos / 1984 / Christmas
```

You can change working folders while keeping the same Picture Library Folder.

## Include Subfolders

When choosing a working folder, dMPP can either look only in that folder or also include folders below it.

With **Include Subfolders** off, dMPP looks only in the selected folder.

With **Include Subfolders** on, dMPP also looks inside folders below the selected folder.

Use Include Subfolders when a set of pictures is organized across nested folders.

## When you reopen dMPP

After the first setup, dMPP remembers your Picture Library Folder and your most recent working folder.

When you start the app again, dMPP may offer to continue with the folder you used last time or let you choose a different working folder.

Use the previous folder when you want to keep reviewing where you left off.

Choose a new folder when you want to review a different part of the same Picture Library Folder.

If you need to change the main archive root, use **Change or Refresh Picture Library Folder…** instead. That is different from choosing a working folder.

## Changing or refreshing the Picture Library Folder

Use **Change or Refresh Picture Library Folder…** when:

- you chose the wrong archive root
- you moved your picture archive
- macOS or cloud storage no longer allows dMPP to access the folder
- you need to reselect the same folder to refresh access

When changing folders, dMPP checks whether the selected folder already contains `dMagy Portable Archive Data`.

If it does not, dMPP warns before creating a new empty portable archive data folder. This helps prevent the scary feeling that your People, Locations, Tags, or Crops disappeared.

## Cloud storage folders

dMPP can work with folders stored in cloud-backed locations such as Dropbox or iCloud Drive, but macOS permissions and cloud sync can sometimes interrupt access.

If dMPP can see the folder path but cannot read or write archive data, reselect the same Picture Library Folder to refresh access.

## Apple Photos

dMPP does not work directly inside the Apple Photos library.

If your pictures are in Apple Photos, export them to regular folders first. Then choose the exported folder structure as your Picture Library Folder.

## Good habit

Try to have one main `dMagy Portable Archive Data` folder for an archive.

If you accidentally choose a smaller folder and create another portable archive data folder, your shared People, Locations, Tags, and Crops may feel split across multiple archives.
