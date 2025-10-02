

Write-Host ""
Write-Host "what would you like to do?"
Write-Host "A) collect new baseline"
Write-Host "B) Start monitoring files with saved baseline"

$response = Read-Host
Write-Host ""

Function CalcHash($filepath)
{
    $filehash = Get-FileHash -Path $filepath -Algorithm SHA512
    return $filehash
}
Function EraseBaseline()
{
    $baseExists = Test-Path -Path ./Baseline.txt
    $baselinefile = Join-Path $BasePath "Baseline.txt"
    if (Test-Path -Path $baselinefile)
    {
        Remove-Item -Path $baselinefile -Force
        Write-Host "Old Baseline erased"
    }
}

if ($response -ieq "A") 
{
    #calculate hash and store in baseline.txt
    #Define a base folder(inside users profile making it unique to them)
    $BasePath = "$env:USERPROFILE\FIM"

    #check if folder already exists
    if (!(Test-Path $BasePath))
    {
        #create folder if its the first run
        New-Item -ItemType Directory -Path $BasePath | Out-Null
        Write-Host "created new user folder at: $BasePath"
    }
    else
    {
        Write-Host "Using existing folder: $BasePath"
    }


    #delete any baslines that already exist repeatedly
    EraseBaseline

    # ==ADD NEW FILES TO FIM FOLDER==
    #prompt users for files/folders to add
    $source = Read-Host "Enter the path of file/folder u want to add"

    if (Test-Path $source -PathType Leaf)
    {
        Copy-Item -Path $source -Destination $BasePath -Force
        Write-Host "Added file: $source"
    }
    elseif (Test-Path $source -PathType Container)
    {
        Copy-Item -Path "$source\*" -Destination $BasePath -Recurse -Force
        Write-Host "Added files from folder: $source"
    }
    else
    {
        Write-Host "Invalid path!Exiting..." 
        exit
    }

    #collect all files in FIM folder
    $files =Get-ChildItem -Path $BasePath -File -Recurse

    Write-Host "`n== Files in FIM Folder =="
    $files | Select-Object FullName
    

    #for each file , calculate the hash and write to baseline.txt
    foreach ($f in $files)
    {
        $hash = CalcHash $f.FullName
        "$($hash.path)|$($hash.Hash)" | Out-File -FilePath (Join-Path $BasePath "Baseline.txt") -Append
    }

}
elseif ($response -ieq "B")
{
    $HashDirectory = @{}

    #define FIM folder
    $BasePath = "$env:USERPROFILE\FIM"
    $Baselinefile = Join-Path $BasePath "Baseline.txt"
    
    #Load file|hash from baseline.txt and store them in a dictionary
    $FilePash = Get-Content -Path $Baselinefile -ErrorAction SilentlyContinue
    foreach($f in $FilePash)
    {
        $parts = $f.Split("|")
        $HashDirectory.Add($parts[0], $parts[1])
    }


    #begin continuos monitoring files with saved baseline... press ctrl+C to stop...
    while($true)
    {
        Start-Sleep -Seconds 5
        $files =Get-ChildItem -Path $BasePath -Recurse

 
       #for each file , calculate the hash and write to baseline.txt
       foreach ($f in $files)
       {
         $hash = CalcHash $f.FullName

         if ($HashDirectory[$hash.Path] -eq $null)
         {
            #A new file has been created
            Write-Host "$($hash.Path) has been created!" -ForegroundColor Green
         }
         elseif ($HashDirectory[$hash.Path] -ne $hash.Hash)
         {
            #notify user of file compromise
               Write-Host "$($hash.Path) has changed!!!" -ForegroundColor DarkRed -BackgroundColor White
         }
       }
       #check for deleted files
       foreach ($key in $HashDirectory.Keys)
       {
          $baseStillExists = Test-Path -Path $key
          if (-Not (Test-Path -Path $key))
          {
             #one of the baseline files have been deleted
             Write-Host "($($key) has been deleted!" -ForegroundColor DarkRed -BackgroundColor White
          }
       }
    }
}
