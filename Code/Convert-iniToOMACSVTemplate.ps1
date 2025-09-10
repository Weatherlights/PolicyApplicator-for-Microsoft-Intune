<#  
    .Synopsis  
        Converts a target ini file into a csv file that can be imported to intune  
          
    .Description  
        Converts a target ini file into a csv file that can be imported to intune  
          
    .Notes  
        Author        : Hauke Goetze (hauke@hauke.us)
        Version        : 1.0 - 2021/03/19 - Initial release  
                         1.1 - 2021/03/22 - Cleaned up unused variables, cleaning up the AppName variable, added comments
                         1.2 - 2021/09/27 - Escape strings xml compatible
          
          
    .Parameter FilePath  
        The path to the ini file you would like to prepare for intune. 
          
    .Parameter PathOnTargetSystem  
        The path of the file on the target system. You may use system variables here. Mark your variables like %NAME%.
  
    .Parameter AppName  
        The name of the app your file belongs to.
       
     .Parameter AppPolicyName  
        A name for the policy you want to create.
       
     .Parameter Context  
        Specify wether the policy is applied in SYSTEM or USER context.

     .Parameter Operation
        Defines how the PolicyApplicator Agent will apply the configuration on the system. If you don't know what to do here just ignore it.
          
     .Parameter OutputFilePath  
        Specify a filename where you would like to save the intune policy for later upload. 
                  
    .Example  
        .\Convert-iniToOMACSVTemplate.ps1 -FilePath "C:\myApp\myConfig.ini" -PathOnTargetSystem "%SYSTEMDRIVE%\myApp\myConfig.xml" -AppName "myApp" AppPolicyName "myConfig" -Context "Machine" -OutputFilePath "c:\myIntuneReadyConfig.csv"  
        -----------  
        Description  
        Converts the file c:\myApp\myConfig.ini into c:\myIntuneReadyConfig.csv. You can upload the csv file later and deploy it using Intune. The policy will be applied as SYSTEM user.
    #>  
param(
    [ValidateNotNullOrEmpty()]  
    [ValidateScript({Test-Path $_})]  
    [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
    [string]$FilePath,

    [Parameter(Mandatory=$True)][string]$PathOnTargetSystem,

    [Parameter(Mandatory=$True)][string]$AppName,
    [Parameter(Mandatory=$True)][string]$AppPolicyName,

    [ValidateSet("User","Machine")]$Context,
    [ValidateSet("Create", "Update", "Replace", "Delete")]$Operation = "Replace",

    [Parameter(Mandatory=$True)][string]$OutputFilePath
);

# Find out where the script as been started from.
$AppDir = $MyInvocation.MyCommand.Path

# Load all the modules from the Modules directory.
$modulesToLoad = Get-ChildItem -Path "$AppDir\..\Modules";
ForEach ( $module in $modulesToLoad ) {
    Import-Module $module.FullName;
}

# This object will hold the configuration that gets exported into the csv file.
$omaConfigs = @();
$omaConfigs += @{}; # We reserve a space for ADMX Install at the front.


$cleanAppPolicyName = ConvertTo-ADMXCompatibleName $AppPolicyName
$cleanAppName = ConvertTo-ADMXCompatibleName $AppName

$outfilePath
if ( $PathOnTargetSystem ) {
    $outfilePath = $PathOnTargetSystem
} else {
    $outfilePath = $FilePath;
}

$regKey = Get-PolicyRegistryKey -AppName $cleanAppName -AppPolicyName $cleanAppPolicyName;


$OMA_SETUP = "./Vendor/MSFT/Policy/ConfigOperations/ADMXInstall/$cleanAppName/Policy/$cleanAppName`_$cleanAppPolicyName"

if ( $Context -eq "Machine" ) {
$OMA_Context = "Device"
} else {
$OMA_Context = "User"
}

$OMA_Base = "./$OMA_Context/Vendor/MSFT/Policy/Config/"

$encoding = Get-FileEncoding -Path $FilePath

$omaConfigFileUri = "$oma_base$cleanAppName~Policy~$cleanAppPolicyName/$cleanAppName-$cleanAppPolicyName-File"

$cleanAppNameXmlCompatible = ConvertTo-XmlCompatibleString $cleanAppName;
$cleanAppPolicyNameXmlCompatible = ConvertTo-XmlCompatibleString $cleanAppPolicyName;
$outFilePathXmlCompatible = ConvertTo-XmlCompatibleString $outFilePath
$encodingXmlCompatible = ConvertTo-XmlCompatibleString $encoding

$omaConfigFile = [PSCustomObject]@{
    "@odata.type" = "#microsoft.graph.omaSettingString";
    "displayName" = $AppName+': '+ $AppPolicyName +" File configuration";
    "description" = ""
    "value" = "<enabled/>
<data id=`"$cleanAppNameXmlCompatible-$cleanAppPolicyNameXmlCompatible-File-path`" value=`"$outFilePathXmlCompatible`"/>
<data id=`"$cleanAppNameXmlCompatible-$cleanAppPolicyNameXmlCompatible-File-operation`" value=`"create`"/>
<data id=`"$cleanAppNameXmlCompatible-$cleanAppPolicyNameXmlCompatible-File-encoding`" value=`"$encodingXmlCompatible`"/>";
    "omauri" = $omaConfigFileUri;
};

$omaConfigs += $omaConfigFile;

$iniContent = Get-IniContent -FilePath $FilePath;
$categories = '<category name="'+$cleanAppPolicyName+'" displayName="$(string.Nothing)" />';
$policies = '';

$i=0;
$iniSectionKeys = $iniContent.Keys | Sort-Object
ForEach ( $sectionname in $iniSectionKeys ) {
    

    $omaattributebase ="$oma_base$cleanAppName~Policy~$cleanAppPolicyName"

    $inisection = $iniContent."$sectionname";
    ForEach ( $keyname in $inisection.Keys ) {
        $value = $inisection."$keyname"
        $policyName = "$cleanAppName-$cleanAppPolicyName-$i"

        $displayName = "";
        if ( $sectionname -ne "__No-Section__" ) {
            $displayName += "[$sectionname] "
        }
        $displayName += $keyname;


        $fullomauri = "$omaattributebase/$policyName"

            $policyNameXmlCompatible = ConvertTo-XmlCompatibleString $policyName;
    $policyValueXmlCompatible = ConvertTo-XmlCompatibleString $value;
    $policyOperationXmlCompatible = ConvertTo-XmlCompatibleString $Operation
    $policySectionNameXmlCompatible = ConvertTo-XmlCompatibleString $sectionname;
    $policyKeyNameNameXmlCompatible = ConvertTo-XmlCompatibleString $keyname;

        $configuredvalue = "<enabled/>
<data id=`"$policyNameXmlCompatible-value`" value=`"$policyValueXmlCompatible`"/>
<data id=`"$policyNameXmlCompatible-operation`" value=`"$policyOperationXmlCompatible`"/>
<data id=`"$policyNameXmlCompatible-section`" value=`"$policySectionNameXmlCompatible`"/>
<data id=`"$policyNameXmlCompatible-key`" value=`"$policyKeyNameNameXmlCompatible`"/>"

        # Define an intune custom profile element.
        $omaConfig = [PSCustomObject]@{
            "@odata.type" = "#microsoft.graph.omaSettingString";
            "displayName" = $displayName;
            "description" = ""
            "value" = $configuredvalue;
            "omauri" = $fullomauri;
        };

        # And add it to the rest.
        $omaConfigs += $omaConfig;
        
        # Build the final ADMX Policy
        $policy = Get-ADMXPolicyForIni -CategoryName $cleanAppPolicyName -PolicyName $policyName -Class $Context -Key "$regKey\$i";


        $policies += $policy;
        $i++;
    }
}
$ADMXContent = Get-ADMXTemplate -AppName $cleanAppName -Categories $categories -Policies $policies -AppPolicyName $cleanAppPolicyName -FileType "ini" -Class $Context;

$config = [PSCustomObject]@{
    "@odata.type" = "#microsoft.graph.omaSettingString";
    "displayName" = $AppName+': '+ $AppPolicyName+" ADMX Install";
    "description" = ""
    "value" = $ADMXContent;
    "omauri" = $oma_setup;
};
 $omaConfigs[0] = $config;


$omaConfigs | Select-Object -Property displayName,description,omauri,value | Export-csv -Path $OutputFilePath -NoTypeInformation

### I use a code signature to sign my files. You may use your own.
# Set-AuthenticodeSignature "$env:userprofile\GitHub\PolicyApplicator-for-Microsoft-Intune\Code\Convert-iniToOMACSVTemplate.ps1" @(Get-ChildItem cert:\CurrentUser\My -codesigning)[0] -TimestampServer http://time.certum.pl
