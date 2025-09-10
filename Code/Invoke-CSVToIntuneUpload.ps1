<#  
    .Synopsis  
        Uploads a csv file that represents a converted intune configuration profile to intune.
          
    .Description  
        Uploads a csv file that represents a converted intune configuration profile to intune. Note this script needs the IntuneGraph module available in the IntuneGraph folder.
          
    .Notes  
        Author        : Hauke Goetze (hauke@hauke.us)
        Version       : 1.0 - 2021/03/19 - Initial release  
                        1.1 - 2021/03/22 - Added switch to forcefully prompt for AdminConsent.
          
    .Parameter FilePath  
        The path to the csv file you would like to upload to intune. 
          
    .Parameter PolicyName  
        The name of the configuration profile created in intune.

    .Parameter AdminConsent  
        Will enforce an administrative consent for the Microsoft Intune PowerShell app.
  
    .Example  
        .\Invoke-CSVToIntuneUpload.ps1 -FilePath "c:\myIntuneReadyConfig.csv" -PolicyName "MyConfig Windows 10 custom configuration profile"
        -----------  
        Description  
        Creates an intune configuration profile named MyConfig Windows 10 custom configuration profile using the file c:\MyIntuneReadyConfig.csv.
    #>  
param(
    [ValidateNotNullOrEmpty()]  
    [ValidateScript({Test-Path $_})]  
    [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
    [string]$FilePath,
    [Parameter(Mandatory=$True)][string]$PolicyName,
    [Parameter][switch]$AdminConsent
)

$AppDir = $MyInvocation.MyCommand.Path

Import-Module "$AppDir\..\IntuneGraph\Microsoft.Graph.Intune.psd1"

if ( $AdminConsent ) {
    Connect-MSGraph -AdminConsent
} else {
    Connect-MSGraph
}

## Get the CSV File back in
$policiesFromCSV = Import-Csv -Path $FilePath
$policies = @();
ForEach ( $policyFromCSV in $policiesFromCSV ) {
    $policy = [PSCustomObject]@{
        "@odata.type" = "#microsoft.graph.omaSettingString";
        "displayName" = $policyFromCSV.displayName;
        "description" = $policyFromCSV.description;
        "value" = $policyFromCsv.value;
        "omaUri" = $policyFromCsv.omauri;
     };
     $policies += $policy;
    
}


New-IntuneDeviceConfigurationPolicy -displayName $PolicyName -ODataType "#microsoft.graph.windows10CustomConfiguration" -omaSettings $policies
