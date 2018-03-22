[CmdletBinding()]

param(
    [Parameter(Mandatory=$True)]
    [string]$buildDefinitionName,
    [Parameter()]
    [string]$artifactDestinationFolder = $Env:BUILD_STAGINGDIRECTORY,
    [Parameter()]
    [switch]$appendBuildNumberVersion = $false
)
    Write-Verbose -Verbose ('buildDefinitionName: ' + $buildDefinitionName)
    Write-Verbose -Verbose ('artifactDestinationFolder: ' + $artifactDestinationFolder)
    Write-Verbose -Verbose ('appendBuildNumberVersion: ' + $appendBuildNumberVersion)

    $tfsUrl = $Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + $Env:SYSTEM_TEAMPROJECT

    $buildDefinitions = Invoke-RestMethod -Uri ($tfsURL + '/_apis/build/definitions?api-version=2.0&name=' + $buildDefinitionName) -Method GET -UseDefaultCredentials
    $buildDefinitionId = ($buildDefinitions.value).id;
    
    $tfsGetLatestCompletedBuildUrl = $tfsUrl + '/_apis/build/builds?definitions=' + $buildDefinitionId + '&statusFilter=completed&resultFilter=succeeded&$top=1&api-version=2.0'

    $builds = Invoke-RestMethod -Uri $tfsGetLatestCompletedBuildUrl -Method GET -UseDefaultCredentials
    $buildId = ($builds.value).id;

    if( $appendBuildNumberVersion)
    {
        $buildNumber = ($builds.value).buildNumber
        $versionRegex = "d+.d+.d+.d+"

        # Get and validate the version data
        $versionData = [regex]::matches($buildNumber,$versionRegex)
        switch($versionData.Count)
        {
           0        
              { 
                 Write-Error "Could not find version number data in $buildNumber."
                 exit 1
              }
           1 {}
           default 
              { 
                 Write-Warning "Found more than instance of version data in buildNumber." 
                 Write-Warning "Will assume first instance is version."
              }
        }
        $buildVersionNumber = $versionData[0]
        $newBuildNumber =  $Env:BUILD_BUILDNUMBER + $buildVersionNumber
        Write-Verbose -Verbose "Version: $newBuildNumber"
        Write-Verbose -Verbose "##vso[build.updatebuildnumber]$newBuildNumber"
    }

    $dropArchiveDestination = Join-path $artifactDestinationFolder "drop.zip"


    #build URI for buildNr
    $buildArtifactsURI = $tfsURL + '/_apis/build/builds/' + $buildId + '/artifacts?api-version=2.0'
    
    #get artifact downloadPath
    $artifactURI = (Invoke-RestMethod -Uri $buildArtifactsURI -Method GET -UseDefaultCredentials).Value.Resource.downloadUrl

    #download ZIP
    Invoke-WebRequest -uri $artifactURI -OutFile $dropArchiveDestination -UseDefaultCredentials 

    #unzip
    Add-Type -assembly 'system.io.compression.filesystem'
    [io.compression.zipfile]::ExtractToDirectory($dropArchiveDestination, $artifactDestinationFolder)

    Write-Verbose -Verbose ('Build artifacts extracted into ' + $Env:BUILD_STAGINGDIRECTORY)