<#  
    .Synopsis  
        Converts a target registry structure into a csv file that can be imported to intune
          
    .Description  
        Converts a target registry structure into a csv file that can be imported to intune. This version does not require the PolicyApplicator to work but does not support QWords, Binary or REG_EXPAND_SZ values.
          
    .Notes  
        Author        : Hauke Goetze (hauke@hauke.us)
        Version        : 1.0 - 2021/03/23 - Initial release.  
          
          
    .Parameter RegistryPath  
        The path to the ini file you would like to prepare for intune. 
          

    .Parameter AppName  
        The name of the app your file belongs to.
       
     .Parameter AppPolicyName  
        A name for the policy you want to create.
          
     .Parameter OutputFilePath  
        Specify a filename where you would like to save the intune policy for later upload. 
                  
    .Example  
        .\Convert-SimpleRegToOMACSVTemplate.ps1 -RegistryPath "HKLM:\SOFTWARE\MyApp" -AppName "myApp" -AppPolicyName "myConfig" -OutputFilePath "c:\myIntuneReadyConfig.csv"  
        -----------  
        Description  
        Takes all values from the registry key HKLM:\SOFTWARE\MyApp and captures them in the csv file.
    #>  
param(
    [ValidateNotNullOrEmpty()]  
    [ValidateScript({Test-Path $_})]  
    [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
    [string]$RegistryPath,

    [Parameter(Mandatory=$True)][string]$AppName,
    [Parameter(Mandatory=$True)][string]$AppPolicyName,

    [Parameter(Mandatory=$True)][string]$OutputFilePath
);

Write-Host "Initializing modules..." -NoNewline
$AppDir = $MyInvocation.MyCommand.Path

$modulesToLoad = Get-ChildItem -Path "$AppDir\..\Modules";
ForEach ( $module in $modulesToLoad ) {
    Import-Module $module.FullName;
}
Write-Host "done!";

$omaConfigs = @();
$omaConfigs += @{};

$cleanAppName = ConvertTo-ADMXCompatibleName $AppName;
$cleanAppPolicyName = ConvertTo-ADMXCompatibleName $AppPolicyName


Write-Host "Reading Registry $RegistryPath recursivly..." -NoNewline;
$registryData = @();
$registryData += Get-ChildItem -Path $RegistryPath -Recurse
$registryData += Get-Item -Path $RegistryPath
Write-Host "done!";
$categories = '<category name="'+$cleanAppPolicyName+'" displayName="$(string.Nothing)" />';
$policies = '';

ForEach ( $registryKey in $registryData ) {
    $valueNames = $registryKey.GetValueNames()

    $registryKeyPath = $registryKey.PSPath -replace "^Microsoft\.PowerShell\.Core\\Registry::", "";

    $cleanRegistryKeyPath = $registryKeyPath -replace "(^HKEY_LOCAL_MACHINE\\|^HKEY_CURRENT_USER\\)", "";

    $class = ""
    if ( $registryKeyPath -match "^HKEY_CURRENT_USER" ) {
        $class = "User"
        $context = "User"
    } elseif ( $registryKeyPath -match "^HKEY_LOCAL_MACHINE" ) {
        $class = "Machine"
        $context = "Device"
    }
    
    if ( $class ) {
        ForEach ( $valueName in $valueNames ) {
            $value = $registryKey.GetValue($valueName);
            $datatype = $registryKey.GetValueKind($valueName);
            Write-Host "Processing $registryKeyPath\$valueName..." -NoNewline;
            $policyname = ($cleanRegistryKeyPath -replace "\\", "-") + "-$valueName";
            if (
                ($datatype -eq "DWord") -or
                ($datatype -eq "string") -or
                ($datatype -eq "MultiString")
            ) {
                $fullomauri = "./$context/Vendor/MSFT/Policy/Config/$cleanAppName~Policy~$cleanAppPolicyName/$policyname";
                $policy = Get-ADMXPolicyForRegistry -Key $cleanRegistryKeyPath -Class $Class -PolicyName $policyname -CategoryName $cleanAppPolicyName -ValueName $valuename -DataType $datatype;
                $policies += $policy;
                if ( $datatype -eq "MultiString" ) {
                    $value = $value -join "&#xF000;";
                }
                $configuredvalue = "<enabled/><data id=`"$policyname-value`" value=`"$value`"/>"

                $omaConfig = [PSCustomObject]@{
                    "@odata.type" = "#microsoft.graph.omaSettingString";
                    "displayName" = "$registryKeyPath\$valueName";
                    "description" = ""
                    "value" = $configuredvalue;
                    "omauri" = $fullomauri;
                };
                $omaConfigs += $omaConfig;
                Write-Host "done!"
            } else {
                Write-Host -ForegroundColor Yellow -Object "Not supported!";
            }
        }

    } else {
        Write-Host -ForegroundColor Yellow -Object "Hive type is not supported!";
    }
}
Write-Host "Creating ADMX-Template..." -NoNewline;
$ADMXContent = '<?xml version="1.0" encoding="utf-8"?>
<!--
This ADMX-Template has been generated with a PolicyApplicator Applicator Conversion Kit
It is highly recommended that you review the generated content before deploying it.

Note that this template may only work when the PolicyApplicator Client is installed on the target system.
-->
<policyDefinitions xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" revision="1.0" xsi:schemaLocation="" schemaVersion="1.0" xmlns="http://www.microsoft.com/GroupPolicy/PolicyDefinitions" >
	<policyNamespaces >
		<target prefix="' + $cleanAppName + '" namespace="'+$AppName+'.'+ $cleanAppPolicyName +'.Policies" />
	</policyNamespaces>
	<resources minRequiredRevision="1.0" fallbackCulture="en-us" />
	<supportedOn >
		<definitions >
			<definition name="SupportedOn" displayName="$(string.Nothing)" />
		</definitions>
	</supportedOn>
	<categories >'+$categories+'</categories>
    <policies >'+$policies+'</policies>
</policyDefinitions>'

$omasetupuri = "./Vendor/MSFT/Policy/ConfigOperations/ADMXInstall/$cleanAppName/Policy/$cleanAppName`_$cleanAppPolicyName"

$omaConfig = [PSCustomObject]@{
    "@odata.type" = "#microsoft.graph.omaSettingString";
    "displayName" = $AppName+': '+ $AppPolicyName+" ADMX Install";
    "description" = ""
    "value" = $ADMXContent;
    "omauri" = $omasetupuri;
};
 $omaConfigs[0] = $omaConfig;
 Write-Host "done!";
 Write-Host "Writing output to $OutputFilePath..." -NoNewline
$omaConfigs | Select-Object -Property displayName,description,omauri,value | Export-csv -Path $OutputFilePath -NoTypeInformation
Write-Host "done!";

### I use a code signature to sign my files. You may use your own.
