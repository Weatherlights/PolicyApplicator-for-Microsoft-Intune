    <#  
    .Synopsis  
        Converts a target json file into a csv file that can be imported to intune  
          
    .Description  
        Converts a target json file into a csv file that can be imported to intune  
          
    .Notes  
        Author        : Hauke Goetze (hauke@hauke.us)
        Version        : 1.0 - 2021/09/17 - Initial release
                         1.1 - 2021/09/27 - Escape strings xml compatible  
          
          
    .Parameter FilePath  
        The path to the json file you would like to prepare for intune. 
          
    .Parameter PathOnTargetSystem  
        The path of the file on the target system. You may use system variables here. Mark your variables like %NAME%.
  
    .Parameter AppName  
        The name of the app your file belongs to.
       
     .Parameter AppPolicyName  
        A name for the policy you want to create.
       
     .Parameter Context  
        Specify wether the policy is applied in Machine or User context.

     .Parameter Operation
        Defines how the PolicyApplicator Agent will apply the configuration on the system. If you don't know what to do here just ignore it.
          
     .Parameter OutputFilePath  
        Specify a filename where you would like to save the intune policy for later upload. 
                  
    .Example  
        .\Convert-JSONToOMACSVTemplate.ps1 -FilePath "C:\myApp\myConfig.json" -PathOnTargetSystem "%SYSTEMDRIVE%\myApp\myConfig.json" -AppName "myApp" AppPolicyName "myConfig" -Context "Machine" -OutputFilePath "c:\myIntuneReadyConfig.csv"  
        -----------  
        Description  
        Converts the file c:\myApp\myConfig.json into c:\myIntuneReadyConfig.csv. You can upload the csv file later and deploy it using Intune. The policy will be applied as SYSTEM user.
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


$AppDir = $MyInvocation.MyCommand.Path

$modulesToLoad = Get-ChildItem -Path "$AppDir\..\Modules";
ForEach ( $module in $modulesToLoad ) {
    Import-Module $module.FullName;
}


$jsonFileContent = Get-Content $FilePath;

$jsonPathsToConfigure = Invoke-ParseJSonStructure -InputObject $jsonFileContent

$Class = "User";
if ( $Context -eq "Machine" ) {
    $Class = "Device";
}

$cleanAppPolicyName = ConvertTo-ADMXCompatibleName $AppPolicyName;

$outfilePath
if ( $PathOnTargetSystem ) {
    $outfilePath = $PathOnTargetSystem
} else {
    $outfilePath = $FilePath;
}

$regkey = Get-PolicyRegistryKey -AppName $AppName -AppPolicyName $cleanAppPolicyName

$categories = '<category name="'+$cleanAppPolicyName+'" displayName="$(string.Nothing)" />';
$categoriesMap = @{};
$policyMap = @();

for ( $i=0; $i -lt $jsonPathsToConfigure.Count; $i++ ) {
    $jsonPathToConfigure = $jsonPathsToConfigure[$i];
    
    $nodes = ConvertFrom-JSon $jsonPathToConfigure.Path;
    
    $displayName = "/";
    For ($j = 0; $j -lt $nodes.Count; $j++ ) {
        $nodeDisplayName = $nodes[$j]
        if ( $nodes[$j].GetType().Name -eq "Int32" ) {
            $displayName += "[$nodeDisplayName]";
        } else {
            $displayName += "/$nodeDisplayName";
        }
        
    }

    $displayName = $displayName -replace "^/",""

    $policyFullName = "$AppName-$cleanAppPolicyName-$i";
    $policy = @{
        "PolicyCategoryName" = $cleanAppPolicyName;
        "PolicyName" = $policyFullName
        "PolicyDisplayName" = $displayName;
        "jsonPath" = $jsonPathToConfigure.Path;
        "Operation" = $Operation
        "Value" = $jsonPathToConfigure.Value;
    };
    $policyMap += $policy;

}

$OMABASE = "./$Class/Vendor/MSFT/Policy/Config/"
$OMASETUP = "./Vendor/MSFT/Policy/ConfigOperations/ADMXInstall/$AppName/Policy/$AppName`_$cleanAppPolicyName"


$omaConfigs = @();
$omaConfigs += @{};

$encoding = Get-FileEncoding -Path $FilePath

$omaConfigFileUri = "$OMABASE$AppName~Policy~$cleanAppPolicyName/$AppName-$cleanAppPolicyName-File"

$AppNameXmlCompatible = ConvertTo-XmlCompatibleString $AppName;
$cleanAppPolicyNameXmlCompatible = ConvertTo-XmlCompatibleString $cleanAppPolicyName;
$outFilePathXmlCompatible = ConvertTo-XmlCompatibleString $outFilePath
$encodingXmlCompatible = ConvertTo-XmlCompatibleString $encoding

$omaConfigFile = [PSCustomObject]@{
    "@odata.type" = "#microsoft.graph.omaSettingString";
    "displayName" = $AppName+': '+ $cleanAppPolicyName +" File configuration";
    "description" = ""
    "value" = "<enabled/><data id=`"$AppNameXmlCompatible-$cleanAppPolicyNameXmlCompatible-File-path`" value=`"$outFilePathXmlCompatible`"/><data id=`"$AppNameXmlCompatible-$cleanAppPolicyNameXmlCompatible-File-operation`" value=`"create`"/><data id=`"$AppName-$cleanAppPolicyName-File-encoding`" value=`"$encodingXmlCompatible`"/>";
    "omauri" = $omaConfigFileUri;
};

$omaConfigs += $omaConfigFile;
$policies = "";

For ( $i = 0; $i -lt $policyMap.count; $i++ ) {

    ##### Build OMA-DM Information ####
    $policyCategoryName = ConvertTo-ADMXCompatibleName $policyMap[$i].PolicyCategoryName;
    $policyName = ConvertTo-ADMXCompatibleName $policyMap[$i].PolicyName;
    $policyValue = $policyMap[$i].Value;
    $policyOperation = $policyMap[$i].Operation;
    $policyjsonPath = $policyMap[$i].jsonPath;
    $dataType = $policyValue.getType().Name;

    $policy = Get-ADMXPolicyForJson -PolicyName $policyName -CategoryName $policyCategoryName -Class $Context -Key "$regkey\$i"
    $policies += $policy;
    
    $policyOMAURI ="$OMABASE$AppName~Policy~$policyCategoryName/$policyName"
   
    $policyNameXmlCompatible = ConvertTo-XmlCompatibleString $policyName;
    $policyValueXmlCompatible = ConvertTo-XmlCompatibleString $policyValue;
    $policyOperationXmlCompatible = ConvertTo-XmlCompatibleString $policyOperation
    $policyjsonPathXmlCompatible = ConvertTo-XmlCompatibleString $policyjsonPath -IgnoreQuotes;
    $dataTypeXmlCompatible = ConvertTo-XmlCompatibleString $dataType;

    $configuredValue = '<enabled/>
<data id="'+$policyNameXmlCompatible+'-value" value='''+$policyValueXmlCompatible+'''/>
<data id="'+$policyNameXmlCompatible+'-operation" value='''+$policyOperationXmlCompatible+'''/>
<data id="'+$policyNameXmlCompatible+'-jsonpath" value='''+$policyjsonPathXmlCompatible+'''/>
<data id="'+$policyNameXmlCompatible+'-datatype" value='''+$dataTypeXmlCompatible+'''/>'

     $omaConfig = [PSCustomObject]@{
            "@odata.type" = "#microsoft.graph.omaSettingString";
            "displayName" = $policyMap[$i].PolicyDisplayName;
            "description" = ""
            "value" = $configuredValue;
            "omauri" = $policyOMAURI;
       };

       $omaConfigs += $omaConfig;
}

$admxTemplate = Get-ADMXTemplate -AppName $AppName -Categories $categories -Policies $policies -AppPolicyName $cleanAppPolicyName -FileType "json" -Class $Context;


$omaConfigSetup = [PSCustomObject]@{
    "@odata.type" = "#microsoft.graph.omaSettingString";
    "displayName" = $AppName+': '+ $cleanAppPolicyName +" ADMX Install";
    "description" = ""
    "value" = $admxTemplate;
    "omauri" = $OMASETUP;
};

$omaConfigs[0] = $omaConfigSetup;

$omaConfigs | Select-Object -Property displayName,description,omauri,value | Export-csv -Path $OutputFilePath -NoTypeInformation

# Set-AuthenticodeSignature "$env:userprofile\GitHub\PolicyApplicator-for-Microsoft-Intune\Code\Convert-JSonToOMACSVTemplate.ps1" @(Get-ChildItem cert:\CurrentUser\My -codesigning)[0] -TimestampServer http://time.certum.pl
