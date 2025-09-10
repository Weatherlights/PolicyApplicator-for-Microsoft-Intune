    <#  
    .Synopsis  
        Converts a target list file into a csv file that can be imported to intune  
          
    .Description  
        Converts a target list file into a csv file that can be imported to intune  
          
    .Notes  
        Author        : Hauke Goetze (hauke@hauke.us)
        Version        : 1.0 - 2021/03/19 - Initial release  
                         1.1 - 2021/09/27 - Escape strings xml compatible
          
          
    .Parameter FilePath  
        The path to the list file you would like to prepare for intune. 
          
    .Parameter PathOnTargetSystem  
        The path of the file on the target system. You may use system variables here. Mark your variables like %NAME%.
  
    .Parameter AppName  
        The name of the app your file belongs to.
       
     .Parameter AppPolicyName  
        A name for the policy you want to create.
       
     .Parameter Context  
        Specify wether the policy is applied in SYSTEM or USER context.
          
     .Parameter OutputFilePath  
        Specify a filename where you would like to save the intune policy for later upload. 
                  
    .Example  
        .\Convert-ListToOMACSVTemplate.ps1 -FilePath "C:\myApp\sites.exception" -PathOnTargetSystem "%SYSTEMDRIVE%\myApp\myConfig.xml" -AppName "myApp" AppPolicyName "SiteList" -Context "Machine" -OutputFilePath "c:\myIntuneReadyConfig.csv"  
        -----------  
        Description  
        Converts the file c:\myApp\sites.exception into c:\myIntuneReadyConfig.csv. You can upload the csv file later and deploy it using Intune. The policy will be applied as SYSTEM user.
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


    [Parameter(Mandatory=$True)][string]$OutputFilePath
);

$AppDir = $MyInvocation.MyCommand.Path

$modulesToLoad = Get-ChildItem -Path "$AppDir\..\Modules";
ForEach ( $module in $modulesToLoad ) {
    Import-Module $module.FullName;
}

$cleanAppPolicyName = ConvertTo-ADMXCompatibleName $AppPolicyName;

$outfilePath
if ( $PathOnTargetSystem ) {
    $outfilePath = $PathOnTargetSystem;
} else {
    $outfilePath = $FilePath;
}


$regkey = Get-PolicyRegistryKey -AppName $AppName -AppPolicyName $cleanAppPolicyName


$Class = "User";
if ( $Context -eq "Machine" ) {
    $Class = "Device";
}


$listFileContent = Get-Content $FilePath;

$categories = '<category name="'+$cleanAppPolicyName+'" displayName="$(string.Nothing)" />';


$OMABASE = "./$Class/Vendor/MSFT/Policy/Config/"
$OMASETUP = "./Vendor/MSFT/Policy/ConfigOperations/ADMXInstall/$AppName/Policy/$AppName`_$cleanAppPolicyName"


#ForEach ( $categoryName in $categoriesMap.Keys ) {
#    $category = Get-ADMXCategory -Name $categoryName -Parent $categoriesMap[$categoryName];
#    $categories += $category;
#}

$encoding = Get-FileEncoding -Path $FilePath


$omaConfigs = @();
$omaConfigs += @{};

$omaConfigFileUri = "$OMABASE$AppName~Policy~$cleanAppPolicyName/$AppName-$cleanAppPolicyName-File"

$AppNameXmlCompatible = ConvertTo-XmlCompatibleString $AppName;
$cleanAppPolicyNameXmlCompatible = ConvertTo-XmlCompatibleString $cleanAppPolicy;
$outFilePathXmlCompatible = ConvertTo-XmlCompatibleString $outFilePath
$encodingXmlCompatible = ConvertTo-XmlCompatibleString $encoding


$omaConfigFile = [PSCustomObject]@{
    "@odata.type" = "#microsoft.graph.omaSettingString";
    "displayName" = $AppName+': '+ $AppPolicyName +" File configuration";
    "description" = ""
    "value" = "<enabled/>
<data id=`"$AppNameXmlCompatible-$cleanAppPolicyNameXmlCompatible-File-path`" value=`"$outFilePathXmlCompatible`"/>
<data id=`"$AppNameXmlCompatible-$cleanAppPolicyNameXmlCompatible-File-operation`" value=`"create`"/>
<data id=`"$AppNameXmlCompatible-$cleanAppPolicyNameXmlCompatible-File-encoding`" value=`"$encodingXmlCompatible`"/>";
    "omauri" = $omaConfigFileUri;
};

$omaConfigs += $omaConfigFile;

$policyName = ConvertTo-ADMXCompatibleName "$AppName-$cleanAppPolicyName-0";

$policies = Get-ADMXPolicyForList -CategoryName $cleanAppPolicyName -PolicyName $policyName -Class $Context -Key "$regkey\0";

    ##### Build OMA-DM Information ####
$dataValueList = "";
For ( $i = 0; $i -lt $listFileContent.count; $i++ ) {

    $listEntry = $listFileContent[$i];
    $NrListEntry = $i+1;

    $listEntryXmlCompatible = ConvertTo-XmlCompatibleString $listEntry;

    $dataValueList += "$NrListEntry&#xF000;$listEntryXmlCompatible&#xF000;"
}
$dataValueList = $dataValueLIst -replace "&#xF000;$","";

$policyOMAURI ="$OMABASE$AppName~Policy~$cleanAppPolicyName/$policyName"

$policyNameXmlCompatible = ConvertTo-XmlCompatibleString $policyName;


$configuredValue = '<enabled/>
<data id="'+$policyNameXmlCompatible+'-list" value="'+$dataValueList+'"/>
<data id="'+$policyNameXmlCompatible+'-operation" value="Replace"/>';

$omaConfig = [PSCustomObject]@{
    "@odata.type" = "#microsoft.graph.omaSettingString";
    "displayName" = $AppName+': '+ $AppPolicyName +" List";
    "description" = ""
    "value" = $configuredValue;
    "omauri" = $policyOMAURI;
};

$omaConfigs += $omaConfig;


$admxTemplate = Get-ADMXTemplate -AppName $AppName -Categories $categories -Policies $policies -AppPolicyName $cleanAppPolicyName -FileType "list" -Class $Context;


$omaConfigSetup = [PSCustomObject]@{
    "@odata.type" = "#microsoft.graph.omaSettingString";
    "displayName" = $AppName+': '+ $AppPolicyName +" ADMX Install";
    "description" = ""
    "value" = $admxTemplate;
    "omauri" = $OMASETUP;
};

$omaConfigs[0] = $omaConfigSetup;

$omaConfigs | Select-Object -Property displayName,description,omauri,value | Export-csv -Path $OutputFilePath -NoTypeInformation
