Import-Module .\IntuneWin32App.psm1 -Force

$filename = "C:\temp\SharePoint Site Info.csv"
#$root = "c:\temp\shortcuts\"
#$exe = "C:\temp\shortcuts\CopyFileToUserDesktop.exe"
#$build = "c:\temp\shortcuts\build.cmd"
#$detect = "c:\temp\shortcuts\Detect.ps1"
$rootpath = "C:\Users\ccobb\Douglas J Institute\IT Collaborative Initiatives - General\Application Deployment\Douglas J\secureOneDriveLink"
$version = "2"

#Must connect to intune first or you get an interesting error.
Connect-MSIntuneGraph -TenantID "douglasj.com"
Connect-MGGraph -Verbose  #-Scopes "User.Read.All,Group.Read.All"


$csv = Import-Csv -Path $filename

$csv | Get-Member

$item = $csv[67]
$item
if( (Test-AccessToken) -eq $false)
{
    Connect-MSIntuneGraph -TenantID "douglasj.com" -Refresh
}

foreach( $item in $csv)
{
    if( $item.group -eq 2)
    {
    #$item.'S:\ drive folder'


    # Install / Uinstall Commands
    $webTitle = Split-Path $item.webUrl -Leaf

    #Deploy-Application.exe -DeploymentType Install -DeployMode Silent -siteID {a39cf640-af91-4ac5-89a5-da1447fce164} -webTitle Secure_Project-FreedomImplementation -webURL https://douglasj.sharepoint.com/sites/Secure_Project-FreedomImplementation -listId {142617eb-1305-4967-b733-d111680116d7} -listTitle Files -webId {baed4253-bbcb-4560-b5d9-4a78de5960d8}"
    #Deploy-Application.exe -DeploymentType Uninstall -DeployMode Silent -siteID {a39cf640-af91-4ac5-89a5-da1447fce164} -webTitle Secure_Project-FreedomImplementation -webURL https://douglasj.sharepoint.com/sites/Secure_Project-FreedomImplementation -listId {142617eb-1305-4967-b733-d111680116d7} -listTitle Files -webId {baed4253-bbcb-4560-b5d9-4a78de5960d8}"
    $installCommandLine = "Deploy-Application.exe -DeploymentType Install -DeployMode Silent " +
                "-siteID '{$($item.siteId)}' " +
                "-webTitle $($webTitle) " +
                "-webUrl $($item.webUrl) " +
                "-listID '{$($item.listId)}' " +
                "-listTitle Files " +
                "-webId '{$($item.webId)}'" 

    $uninstallCommandLine = "Deploy-Application.exe -DeploymentType Uninstall -DeployMode Silent " +
                "-siteID '{$($item.siteId)}' " +
                "-webTitle $($webTitle) " +
                "-webUrl $($item.webUrl) " +
                "-listID '{$($item.listId)}' " +
                "-listTitle Files " +
                "-webId '{$($item.webId)}'"
    
    Write-Host "Install Command   $($installCommandLine)"
    Write-Host "Uninstall Command $($uninstallCommandLine)"

    # Create an Install batch file
    $InstallBatchFileName = $rootpath + "\Install_$($webTitle).bat"
    ".\$($version)\$($installCommandLine)" | Out-File -FilePath $InstallBatchFileName -Encoding ascii
    # Create an Unstaill batch file
    $UnInstallBatchFileName = $rootpath + "\Uninstall_$($webTitle).bat"
    ".\$($version)\$($uninstallCommandLine)" | Out-File -FilePath $UnInstallBatchFileName -Encoding ascii
    
    #
    # Build the app in intune online
    #
    $appName = $webTitle.Replace("Secure_","")
    $appName = "secureOneDriveLink - $($appName)"

    $Win32App = @(Get-IntuneWin32App -DisplayName $appName | Where-Object {$_.displayName -like "$($appName)"})
    if( $Win32App.Count -eq 1 )
    {
        if( $Win32App[0].publishingState -ne "published")
        {
            Write-Host "Item is not properly published $($webTitle)"
            Remove-IntuneWin32App -ID $Win32App[0].ID
        }
    }
    
    if( $Win32App.count -eq 0)
    {
        Write-Host "Item needs to be deployed $($webTitle)"


        Set-Location $rootpath 
        #& ($rootpath + "build.cmd") 1
        #Start-Process -PassThru -FilePath $build -Wait -WorkingDirectory $root -NoNewWindow -ArgumentList 1

        $SourceFolder = $rootpath + "\$($version)-Installer"
        #$SetupFile = $installFile
        #$OutputFolder = "c:\Temp\Output"
        $IntuneWinFile = $sourceFolder + "\" + "Deploy-Application.intunewin"

        $DisplayName = $appName
        $Publisher = "Douglas J"
        $RequirementRules =New-Object -TypeName "System.Collections.ArrayList"
        $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture All -MinimumSupportedWindowsRelease "W10_1607"
        $RequirementRuleScript = New-IntuneWin32AppRequirementRuleScript -ScriptFile "$($rootpath)\OneDrive_Requirement.ps1" -BooleanOutputDataType -BooleanComparisonOperator equal -BooleanValue True -ScriptContext user
        $RequirementRules.Add( $RequirementRuleScript)

        # Create a temp .ps1 based on a template file for the detection rule

        $script = Get-Content -Path "$($rootpath)\template_Onedrive_Shortcut_InstallValidate.ps1"
        $script = $script -replace "--webTitle--", ('"' + $webTitle + '"')
        $script | Set-Content -Path ($env:Temp + "Detect.ps1")
        $DetectionRule = New-IntuneWin32AppDetectionRuleScript -ScriptFile ($env:Temp + "Detect.ps1") -EnforceSignatureCheck $false -RunAs32Bit $false

        #$ImageFile = $rootpath + "\1\" + $iconFile
        #$Icon = New-IntuneWin32AppIcon -FilePath $imageFIle 
        Add-IntuneWin32App -FilePath $IntuneWinFile -DisplayName $DisplayName -Description ("Install " +$appName) -Publisher $Publisher -InstallExperience user -RestartBehavior "suppress" -DetectionRule $DetectionRule -RequirementRule $RequirementRule -AdditionalRequirementRule $RequirementRules -InstallCommandLine $installCommandLine -UninstallCommandLine $uninstallCommandLine -AppVersion 2 -Verbose 

    }

    
    #Get the AppID since we hopefully have a deployed app
    $appName = $webTitle.Replace("Secure_","")
    $appName = "secureOneDriveLink - $($appName)"
    $Win32App = @(Get-IntuneWin32App -DisplayName $appName | Where-Object {$_.displayName -like "$($appName)"})

    if( $Win32App.count -eq 1)
    {
        #Unstall from All Users
        Add-IntuneWin32AppAssignmentAllUsers -ID $WIn32App[0].ID -Intent uninstall -Notification showReboot -Verbose

        $Group_RW = "sec_FS_$($webTitle)__M"
        $Group_RW_ID = @(Get-MgGroup -Filter "displayName eq '$($Group_RW)'")
        if($Group_RW_ID.Count -eq 1)
        {

            Add-IntuneWin32AppAssignmentGroup -ID $Win32App[0].ID -Include -GroupID $Group_RW_ID[0].Id -Intent required -Verbose -Notification showReboot
            Add-IntuneWin32AppAssignmentGroup -ID $Win32App[0].ID -Exclude -GroupID $Group_RW_ID[0].Id -Intent uninstall -Verbose

        }
        else {
            Write-Host "$Group_RW has $($Group_RW_ID.Count) instances.  Skipping adding to deployment"
        }

        $Group_R = "sec_FS_$($webTitle)__R"
        $Group_R_ID = @(Get-MgGroup -Filter "displayName eq '$($Group_R)'")
        if($Group_R_ID.Count -eq 1)
        {
            Add-IntuneWin32AppAssignmentGroup -ID $Win32App[0].ID -Include -GroupID $Group_R_ID[0].Id -Intent required -Verbose -Notification showReboot
            Add-IntuneWin32AppAssignmentGroup -ID $Win32App[0].ID -Exclude -GroupID $Group_R_ID[0].Id -Intent uninstall -Verbose
            
        }

        else {
            Write-Host "$Group_R has $($Group_R_ID.Count) instances.  Skipping adding to deployment"
        }

    }
    else #can't find or multiple with the same name
    {
        Write-Host "App Name $($appName) has $($Win32App.count) instances.  Can't add groups."
    }
}
}

