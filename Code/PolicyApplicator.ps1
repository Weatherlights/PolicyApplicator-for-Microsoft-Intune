################# PHAT PolicyApplicator ##################
###### powered by weatherlights.com ######################
# Author: Hauke Goetze (hgo@phatconsulting.de)
# Version 1.0
# ##################################
param(
        [ValidateSet("Detect","Remediate")]  
        [Parameter()]  
        [string]$Action = "Remediate",
        [ValidateSet("User","System")]  
        [Parameter()]  
        [string]$Context = "User"
)

$repository = "Software\Policies\weatherlights.com\PolicyApplicator"


$AppDir = $MyInvocation.MyCommand.Path

$modulesToLoad = Get-ChildItem -Path "$AppDir\..\Modules";
ForEach ( $module in $modulesToLoad ) {
    Import-Module $module.FullName;
}

Write-LogFile -InputObject "====================== Script has started ======================";
Write-LogFile -InputObject "RunMode: $Action";
### Determine wether we run as System or not.
if ( $context -eq "System" ) {
    $registryRoot = "HKLM" #if we run as system we modify the system context
} else {
    $registryRoot = "HKCU" #if we run as user we modify the user context
}

$registryBase = "$registryRoot`:\$repository"
Write-LogFile -InputObject "RegistryBase: $registryBase";

$configs = Get-PolicyApplicatorConfiguration -RegistryPath $registryBase;
Write-LogFile -InputObject "Retrived configuration from registry";
$compliance = "Compliant"
ForEach ( $config in $configs ) {
    $filePath = $config.FilePath;
    $fileType = $config.FileType;
    $returned_compliance = "";
    Write-LogFile -InputObject "Working on file $filepath with type $fileType.";
    switch ( $config.FileType ) {
        "ini" {
            $returned_compliance = Invoke-IniRemediation -Action $Action -FilePath $filePath -Rules $config.Rules -Operation $config.Operation -Encoding $Config.Encoding
            if ( $returned_compliance -ne "Compliant" ) {
                $compliance = "Non-Compliant";
            }
         }
         "list" {
            $returned_compliance = Invoke-ListRemediation -Action $Action -FilePath $filePath -Rules $config.Rules -Operation $config.Operation -Encoding $Config.Encoding
            if ( $returned_compliance -ne "Compliant" ) {
                $compliance = "Non-Compliant";
            }
         }
         "xml" {
            $returned_compliance = Invoke-XmlRemediation -Action $Action -FilePath $filePath -Rules $config.Rules -Operation $config.Operation -Encoding $Config.Encoding 
            if ( $returned_compliance -ne "Compliant" ) {
                $compliance = "Non-Compliant";
            }
         }
         "json" {
            $returned_compliance = Invoke-JsonRemediation -Action $Action -FilePath $filePath -Rules $config.Rules -Operation $config.Operation -Encoding $Config.Encoding 
            if ( $returned_compliance -ne "Compliant" ) {
                $compliance = "Non-Compliant";
            }
         }
    }
    Write-LogFile -InputObject "$Action for file reported $returned_compliance";

}
Write-LogFile -InputObject "=========== Skript finished with compliance state $compliance ===========";
if ( $compliance -eq "Non-Compliant" ) {
   exit 1;
} else {
    exit 0;
}

# Set-AuthenticodeSignature "$env:userprofile\GitHub\PolicyApplicator-for-Microsoft-Intune\Code\PolicyApplicator.ps1" @(Get-ChildItem cert:\CurrentUser\My -codesigning)[0] -TimestampServer http://time.certum.pl
