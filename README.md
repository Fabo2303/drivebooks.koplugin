# Drive Books for KOReader

Drive Books is an experimental KOReader plugin that lets you browse a public Google Drive folder and download files, mainly to use as a small book library from a shared Drive directory.

## Features

- Browse a shared Google Drive folder from KOReader
- Navigate through nested folders
- Download files directly to the device
- Keep a default shared folder ID ready to use
- Validate the connection to Google Drive before browsing

## Requirements

This plugin depends on the following KOReader modules being available:

- `ssl.https`
- `ltn12`
- `rapidjson`
- `libs/libkoreader-lfs`

It is intended for use on devices where KOReader has these libraries enabled and working.

## Installation

Copy the `drivebooks.koplugin` folder into:

`/mnt/us/koreader/plugins/drivebooks.koplugin/`

Then restart KOReader and open the main menu. You should see a menu entry named `Drive Books` in `Tools`.

## Configuration

Before using the plugin, configure a Google Drive API key:

1. Create a project in the Google Cloud Console.
2. Enable the Google Drive API.
3. Create an API key and restrict it to the Google Drive API.
4. Open `Drive Books` in KOReader.
5. Select `Configure API Key` and paste your key.
6. Optionally change the shared folder ID with `Change shared folder`.
7. Use `Test connection` to verify that the Drive API responds correctly.
8. Then select `Browse Drive books`.

Important: the folder and files must be readable by anyone with the link. A Google API key does not grant access to private files.

## Default folder

The plugin includes a default shared folder ID, so it can be used immediately for a public folder setup. You may update this value to another shared Drive folder if needed.

## Downloads

Downloaded files are saved in:

`/mnt/us/koreader/DriveBooks/`

The plugin creates the destination folder automatically if it does not exist.

## How it works

The plugin queries the Google Drive API to list files in the configured folder and shows them inside KOReader. When a file is selected, it downloads it directly from Google Drive to the KOReader device storage.

## Known limitations

This version is experimental and has several limitations:

- Not verified on every KOReader version
- Requires the libraries listed above
- Lists files and folders but downloads one file at a time
- Does not export native Google Docs, Sheets, or Slides files
- No progress bar or resume support
- API keys are stored in KOReader settings in plain text
- Downloads are synchronous and may make the UI appear temporarily blocked on large files
- Not a replacement for a more mature plugin such as Drivdle; test it first with a small file

## Troubleshooting

If the plugin does not appear in KOReader:

- Check the KOReader log
- Confirm the folder is named exactly `drivebooks.koplugin`
- Do not place it inside another folder with the same name
- Make sure the plugin directory is in the correct KOReader plugins path

If connection fails:

- Verify the Google Drive API is enabled
- Check that the API key is valid and not restricted incorrectly
- Confirm the shared folder is publicly readable
- Test the folder ID carefully; it should be the folder ID, not the full public URL

## License

This project is distributed as-is for personal and experimental use. See the source files in the repository for any additional licensing details or project-specific notices.
