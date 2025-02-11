# Snipping-Tool-Uploader
Extends Windows Snipping Tool functionality by using Powershell to upload each saved screenshot to a remote host, in the likes of other pieces of software to take and upload screenshots.

## Setup
* Clone or download the repository.
* Right click inside your local copy folder and create a new shortcut pointing to snip.ps1 with any name you want.
* Right click the shortcut, go to Properties.
* Set Target to ***C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "full path to the script file"***
* Click Change Icon and insert ***%SystemRoot%\System32\SnippingTool.exe*** in the browsing address bar to get the Snipping Tool Icon.
* Drag the shortcut to wherever you want, ie the windows task bar.

## Usage
* Launch the shortcut and minimize the popup terminal/powershell window.
* Use the launched Windows Snipping Tool as you would normally and save the image as png to $OSPicturesPath set in the script.
* The image will automatically be renamed to yyyy-mm-dd_hh-mm-ss_name.png and moved to a Screenshots\yyyy-mm subfolder.
* The image will automatically be uploaded and the resulting link will be copied to your clipboard. The Snipping Tool will close.

## Logging
Assuming you do not modify the script, the subfolder Screenshots will contain two text files. 

**snip_log.txt** will verbosely log the script actions, helping you debug potential issues if necessary.

**snip_history.txt** will save a upload history log of your files in the following format: **ScreenshotFullPath DirectLink DeletionLink**

Accessing the deletion link through a browser or curl request will remove that image from the host.

