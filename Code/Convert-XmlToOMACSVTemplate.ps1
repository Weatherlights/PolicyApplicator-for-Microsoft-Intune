    <#  
    .Synopsis  
        Converts a target xml file into a csv file that can be imported to intune  
          
    .Description  
        Converts a target xml file into a csv file that can be imported to intune  
          
    .Notes  
        Author        : Hauke Goetze (hauke@hauke.us)
        Version        : 1.0 - 2021/03/19 - Initial release
                         1.1 - 2021/09/27 - Escape strings xml compatible  
          
          
    .Parameter FilePath  
        The path to the xml file you would like to prepare for intune. 
          
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
        .\Convert-XmlToOMACSVTemplate.ps1 -FilePath "C:\myApp\myConfig.xml" -PathOnTargetSystem "%SYSTEMDRIVE%\myApp\myConfig.xml" -AppName "myApp" AppPolicyName "myConfig" -Context "Machine" -OutputFilePath "c:\myIntuneReadyConfig.csv"  
        -----------  
        Description  
        Converts the file c:\myApp\myConfig.xml into c:\myIntuneReadyConfig.csv. You can upload the csv file later and deploy it using Intune. The policy will be applied as SYSTEM user.
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


[xml]$xmlFileContent = Get-Content $FilePath;



$outerXmlObjects = Select-Xml -Xml $xmlFileContent -XPath "(//node()[not(./node())]|//node()/@*)"

$xpathsToConfigure = @();

ForEach ( $xmlObject in $outerXmlObjects ) {
    $node = $xmlObject.Node;
    if ( $node.Name -ne "#comment" ) {
        $xpath = Get-NodeXPath -node $node
        $namespace = Get-NodeNamespaces -node $node
        $value = $node.Value;

        $xpathToConfigure = @{
            "Xpath" = $Xpath;
            "Value" = $Value;
            "Namespace" = $namespace;
            "Operation" = "$Operation";
        };

        $xpathsToConfigure += $xpathToConfigure;
    }
}


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

for ( $i=0; $i -lt $xpathsToConfigure.Count; $i++ ) {
    $xpathToConfigure = $xpathsToConfigure[$i];
    
    $nodes = $xpathToConfigure.Xpath -split "/";
    $nodesToIgnore = 1;
    if ( $nodes[$nodes.Count-1] -eq "text()" ) {
        $nodesToIgnore++;
    }
    $displayName = "";
    For ($j = 1; $j -le $nodes.Count-$nodesToIgnore; $j++ ) {
        $nodeDisplayName = $nodes[$j] -replace "__Default__:", ""; 
        $displayName += "$nodeDisplayName ";
    }

    $displayName = $displayName -replace " $",""

    $policyFullName = "$AppName-$cleanAppPolicyName-$i";
    $policy = @{
        "PolicyCategoryName" = $cleanAppPolicyName;
        "PolicyName" = $policyFullName
        "PolicyDisplayName" = $displayName;
        "xPath" = $xpathToConfigure.Xpath;
        "Operation" = $xpathToConfigure.Operation;
        "Namespace" = $xpathToConfigure.Namespace;
        "Value" = $xpathToConfigure.Value;
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
    $policyxPath = $policyMap[$i].xPath;

    $policy = Get-ADMXPolicyForXml -PolicyName $policyName -CategoryName $policyCategoryName -Class $Context -Key "$regkey\$i"
    $policies += $policy;
    
    $policyOMAURI ="$OMABASE$AppName~Policy~$policyCategoryName/$policyName"

    $policyNamespaceValue = "";

    if ( $policyMap[$i].Namespace.Count -gt 0 ) {
        ForEach ( $namespaceKey in $policyMap[$i].Namespace.Keys ) {
            $namespaceURI = $PolicyMap[$i].Namespace."$namespaceKey";
            $policyNamespaceValue += "$namespaceKey&#xF000;$namespaceURI&#xF000;";
        } 
        $policyNamespaceValue = $policyNamespaceValue -replace "&#xF000;$", "";
    } else {
        $policyNamespaceValue += "__DUMMY__&#xF000;nth://removemeifyouneedtoreplacethis"
    }

    $policyNameXmlCompatible = ConvertTo-XmlCompatibleString $policyName;
    $policyValueXmlCompatible = ConvertTo-XmlCompatibleString $policyValue;
    $policyOperationXmlCompatible = ConvertTo-XmlCompatibleString $policyOperation
    $policyxPathXmlCompatible = ConvertTo-XmlCompatibleString $policyxPath
   
    $configuredValue = '<enabled/>
<data id="'+$policyNameXmlCompatible+'-value" value="'+$policyValueXmlCompatible+'"/>
<data id="'+$policyNameXmlCompatible+'-operation" value="'+$policyOperationXmlCompatible+'"/>
<data id="'+$policyNameXmlCompatible+'-xpath" value="'+$policyxPathXmlCompatible+'"/>
<data id="'+$policyNameXmlCompatible+'-namespace" value="'+$policyNamespaceValue+'"/>';

     $omaConfig = [PSCustomObject]@{
            "@odata.type" = "#microsoft.graph.omaSettingString";
            "displayName" = $policyMap[$i].PolicyDisplayName;
            "description" = ""
            "value" = $configuredValue;
            "omauri" = $policyOMAURI;
       };

       $omaConfigs += $omaConfig;
}

$admxTemplate = Get-ADMXTemplate -AppName $AppName -Categories $categories -Policies $policies -AppPolicyName $cleanAppPolicyName -FileType "xml" -Class $Context;


$omaConfigSetup = [PSCustomObject]@{
    "@odata.type" = "#microsoft.graph.omaSettingString";
    "displayName" = $AppName+': '+ $cleanAppPolicyName +" ADMX Install";
    "description" = ""
    "value" = $admxTemplate;
    "omauri" = $OMASETUP;
};

$omaConfigs[0] = $omaConfigSetup;

$omaConfigs | Select-Object -Property displayName,description,omauri,value | Export-csv -Path $OutputFilePath -NoTypeInformation


#### Bonus Section: You can use this code to test wether your XML file can be reassembled #####
#[xml]$testXml = "";
#ForEach ( $xpathToConfigure in $xpathsToConfigure ) {
#    Set-XmlNodeByXpath -Xpath $xpathToConfigure["Xpath"] -value $xpathToConfigure["Value"] -xml $testXml -Namespace $xpathToConfigure["Namespace"] -Operation $xpathToConfigure["Operation"]
#}
#$testXml.OuterXml | Out-File c:\test\reviewmens.xml

# Set-AuthenticodeSignature "$env:userprofile\GitHub\PolicyApplicator-for-Microsoft-Intune\Code\Convert-XmlToOMACSVTemplate.ps1" @(Get-ChildItem cert:\CurrentUser\My -codesigning)[0] -TimestampServer http://time.certum.pl
