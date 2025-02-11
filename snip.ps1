$OSPicturesPath = [Environment]::GetFolderPath('MyPictures')
$screenshotsFolder = "Screenshots"
$filter = "*.png"
$logFilePaths = @("\snip_log.txt", "\snip_history.txt")
$processed = $false

# Combine paths
$folderPath = Join-Path -Path $OSPicturesPath -ChildPath $screenshotsFolder

# Start the Snipping Tool
Start-Process snippingtool
Write-Host "Snipping Tool started."

# Iterate through each log file path and create it if it doesn't exist
for ($i = 0; $i -lt $logFilePaths.Length; $i++) {
    $fullPath = $folderPath + $logFilePaths[$i]
    Write-Host "Checking path: $fullPath"
    
    # Create the log directory if required
    if (-not (Test-Path -Path (Split-Path $fullPath))) {
        New-Item -ItemType Directory -Path (Split-Path $fullPath) -Force | Out-Null
        Write-Host "Created directory for path: $fullPath"
    }
    
    # Create the log file if required
    if (-not (Test-Path -Path $fullPath)) {
        New-Item -ItemType File -Path $fullPath -Force | Out-Null
        Write-Host "Created log file: $fullPath"
    }
}

$debugLogFilePath = Join-Path -Path $folderPath -ChildPath $logFilePaths[0]
$historyLogFilePath = Join-Path -Path $folderPath -ChildPath $logFilePaths[1]

# Start logging
Start-Transcript -Path $debugLogFilePath -Append

# Define the action to be performed when a new file is created
$action = {
    param ($source, $e)

    if ($processed) {
        return
    }

    $filePath = $e.FullPath
    Write-Host "Detected new file: $filePath"
    $processed = $true

    # Wait for the file to be fully written
    Start-Sleep -Seconds 1

    $currentDate = Get-Date
    $timestamp = $currentDate.ToString("yyyy-MM-dd_HH-mm-ss")
    $subfolderName = "$($currentDate.ToString('yyyy-MM'))"
    $subfolderPath = Join-Path -Path $folderPath -ChildPath $subfolderName

    # Create the subfolder if it doesn't exist
    if (-not (Test-Path -Path $subfolderPath)) {
        New-Item -ItemType Directory -Path $subfolderPath | Out-Null
        Write-Host "Created subfolder: $subfolderPath"
    }

    # Extract the original file name (user-given name without extension)
    $originalFileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)

    # Generate the new file name and path with full timestamp and original file name
    $newFileName = "$timestamp`_$originalFileName.png"
    $newFilePath = Join-Path -Path $subfolderPath -ChildPath $newFileName

    # Move and rename the screenshot to the subfolder
    try {
        Move-Item -Path $filePath -Destination $newFilePath
        Write-Host "Moved file to: $newFilePath"
    } catch {
        Write-Host "Error moving the file: $_"
        return
    }

    try {
        # Upload the screenshot
        Write-Host "Uploading file: $newFilePath"
        $url = "https://kappa.lol/api/upload"
        $boundary = [System.Guid]::NewGuid().ToString()
        $fileContent = [System.IO.File]::ReadAllBytes($newFilePath)
        $contentType = "multipart/form-data; boundary=$boundary"
        $fileHeader = "--$boundary`r`nContent-Disposition: form-data; name=""file""; filename=""$($newFilePath | Split-Path -Leaf)""`r`nContent-Type: image/png`r`n`r`n"
        $fileFooter = "`r`n--$boundary--`r`n"
        $contentBytes = [Text.Encoding]::UTF8.GetBytes($fileHeader) + $fileContent + [Text.Encoding]::UTF8.GetBytes($fileFooter)

        $webRequest = [System.Net.HttpWebRequest]::Create($url)
        $webRequest.Method = "POST"
        $webRequest.ContentType = $contentType
        $webRequest.ContentLength = $contentBytes.Length
        $requestStream = $webRequest.GetRequestStream()
        $requestStream.Write($contentBytes, 0, $contentBytes.Length)
        $requestStream.Close()
        Write-Host "Request sent to $url"

        $response = $webRequest.GetResponse()
        $responseStream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $responseBody = $reader.ReadToEnd().Trim()
        $responseStream.Close()
        $reader.Close()
        $webRequest.Abort()
        Write-Host "Received response: $responseBody"

        # Parse direct link and deletion link
        $responseJson = $responseBody | ConvertFrom-Json
        $link = $responseJson.link
        $delete = $responseJson.delete

        # Copy the link to the clipboard
        $link | Set-Clipboard
        Write-Host "Link copied to clipboard: $link"

        # Log the file, link, and deletion information
        $logEntry = "$newFilePath - $link - $delete"
        Add-Content -Path $historyLogFilePath -Value $logEntry

        # End the Snipping Tool process
        Get-Process -Name "SnippingTool" -ErrorAction SilentlyContinue | Stop-Process -Force
        Write-Host "Snipping Tool process ended."

        # Play a sound
        $soundPath = "C:\Windows\Media\Windows Notify System Generic.wav"
        $player = New-Object System.Media.SoundPlayer $soundPath
        $player.PlaySync()
    } catch {
        Write-Host "Error uploading the screenshot: $_"
    }
}

# Monitor the Pictures folder for changes
$fsw = New-Object IO.FileSystemWatcher $OSPicturesPath, $filter
$fsw.EnableRaisingEvents = $true
$fsw.IncludeSubdirectories = $false
$fsw.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'
Register-ObjectEvent $fsw Created -Action $action

# Keep monitoring while the Snipping Tool is active
while (Get-Process -Name "SnippingTool" -ErrorAction SilentlyContinue) {
    Start-Sleep -Seconds 1
}

# Release the event
$fsw.Dispose()
Stop-Transcript
