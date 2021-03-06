    <#  
    .Synopsis  
        Converts a target xml file into a csv file that can be imported to intune  
          
    .Description  
        Converts a target xml file into a csv file that can be imported to intune  
          
    .Notes  
        Author        : Hauke Goetze (hauke@hauke.us)
        Version        : 1.0 - 2021/03/19 - Initial release  
          
          
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

$omaConfigFile = [PSCustomObject]@{
    "@odata.type" = "#microsoft.graph.omaSettingString";
    "displayName" = $AppName+': '+ $cleanAppPolicyName +" File configuration";
    "description" = ""
    "value" = "<enabled/><data id=`"$AppName-$cleanAppPolicyName-File-path`" value=`"$outFilePath`"/><data id=`"$AppName-$cleanAppPolicyName-File-operation`" value=`"create`"/><data id=`"$AppName-$cleanAppPolicyName-File-encoding`" value=`"$encoding`"/>";
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

   
    $configuredValue = '<enabled/>
<data id="'+$policyName+'-value" value="'+$policyValue+'"/>
<data id="'+$policyName+'-operation" value="'+$policyOperation+'"/>
<data id="'+$policyName+'-xpath" value="'+$policyxPath+'"/>
<data id="'+$policyName+'-namespace" value="'+$policyNamespaceValue+'"/>';

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

# SIG # Begin signature block
# MIIWYAYJKoZIhvcNAQcCoIIWUTCCFk0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJvjmXcsYHEd74/45ZR1dZXzi
# v+agghBKMIIE3DCCA8SgAwIBAgIRAP5n5PFaJOPGDVR8oCDCdnAwDQYJKoZIhvcN
# AQELBQAwfjELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9n
# aWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0
# eTEiMCAGA1UEAxMZQ2VydHVtIFRydXN0ZWQgTmV0d29yayBDQTAeFw0xNjAzMDgx
# MzEwNDNaFw0yNzA1MzAxMzEwNDNaMHcxCzAJBgNVBAYTAlBMMSIwIAYDVQQKDBlV
# bml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLDB5DZXJ0dW0gQ2VydGlm
# aWNhdGlvbiBBdXRob3JpdHkxGzAZBgNVBAMMEkNlcnR1bSBFViBUU0EgU0hBMjCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL9Xi7yRM1ouVzF/JVf0W1NY
# aiWq6IEgzA0dRzhwGqMWN523RHS1GoEk+vUYSjhLC6C6xb80b+qM9Z1CGtAxqFbd
# qCUOtDwlxazGy1zjgJLqo68tAEBAfNJBKB8rCOhR0F2JcCJsaXbQdhI8LksHKSbp
# +AHh0OUo9iTDFfqmkIR0hVyDLA7E2nhJlGodJIaX6SLAxgw14HQyqj27Adh+zBNM
# IMeVLUn28S0XvMYp9/hVdpx9Fdze4UKVk2CZ90PFlEIhvZisHLNm3P14YEQ/PcSV
# aWfuYcva0LnmdvehPwT00+dxryECXhHaU6SmtZF42ZARW7Sh7qduCtlzpDgFUiMC
# AwEAAaOCAVowggFWMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFPM1yo5GCA05jd9B
# xzNuZOQWO5grMB8GA1UdIwQYMBaAFAh2zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1Ud
# DwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAvBgNVHR8EKDAmMCSg
# IqAghh5odHRwOi8vY3JsLmNlcnR1bS5wbC9jdG5jYS5jcmwwawYIKwYBBQUHAQEE
# XzBdMCgGCCsGAQUFBzABhhxodHRwOi8vc3ViY2Eub2NzcC1jZXJ0dW0uY29tMDEG
# CCsGAQUFBzAChiVodHRwOi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3RuY2EuY2Vy
# MEAGA1UdIAQ5MDcwNQYLKoRoAYb2dwIFAQswJjAkBggrBgEFBQcCARYYaHR0cDov
# L3d3dy5jZXJ0dW0ucGwvQ1BTMA0GCSqGSIb3DQEBCwUAA4IBAQDKdOQ4vTLJGjz6
# K1jFVy01UwuQ3i0FsvEzMkAblv8iRYc5rgzwGc7B0DJEGjMMgOs9Myt8eTROxoFE
# NFhWujkN8OSzA6w3dcB667dA9pr8foBtqbRViT2YSMpW9FWkLunh0361OJGVxM+7
# ph51a1ZQm26n69Gc4XEg1dWmWKvh5SldgfEEteQbZEKhOHE9e3NkxmnUIjCWsCTD
# AlsRqDw0YntnZ+FGhld86IqfkLs4W9m1ieoDKNuNt1sHbTK7h3/cJs4uXujWq9vm
# ptDiGQIS+aDbPp1SxEy9V4XteO3BlkTNRrDOZdVXcjokxhDhsHPEj1qDrPbGcpT5
# cnf/AdUhMIIFgjCCBGqgAwIBAgIRANQjhWhMREkjJn7p3s/QCmQwDQYJKoZIhvcN
# AQELBQAwfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3Rl
# cjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQx
# IzAhBgNVBAMTGkNPTU9ETyBSU0EgQ29kZSBTaWduaW5nIENBMB4XDTE4MDUwNDAw
# MDAwMFoXDTIxMDUwMzIzNTk1OVowgc8xCzAJBgNVBAYTAkRFMQ4wDAYDVQQRDAUy
# NDUzNjEbMBkGA1UECAwSU2NobGVzd2lnLUhvbHN0ZWluMRQwEgYDVQQHDAtOZXVt
# w7xuc3RlcjEbMBkGA1UECQwSS2llbGVyIFN0cmFzc2UgMjQyMQ4wDAYDVQQSDAUy
# NDUzNjEZMBcGA1UECgwQSGF1a2UgSGFzc2VsYmVyZzEaMBgGA1UECwwRd2VhdGhl
# cmxpZ2h0cy5jb20xGTAXBgNVBAMMEEhhdWtlIEhhc3NlbGJlcmcwggEiMA0GCSqG
# SIb3DQEBAQUAA4IBDwAwggEKAoIBAQC6A1OjhXNZvBh00rVnXhpeh2uvZWUpYALm
# TWrY/JjPOZ1ic3aglj5tDM4kwzyPcEMyCfxrsWaGxTkDaSuTHQWCty+7CWU8C5KS
# JnAbMn1gAkgB9+9XRFmG8WhzsWEFOKUHFOVvQK4kU5hRBHpRVGP5VLkjRZz/NI4B
# kJrdExtzK2X9kPQibHoKIZbvKBVfD5kwPPxvPARxfhyur4DUZZvpbj90oIhQSckU
# EqtB8yYF/BQNwx2vWXFEy/nd2VrEssIdZ8jgBdRlt8yQX3dm1dOPPDXMLLs8s/Lz
# uzwFwRwkxe8DV6uK2JZLPlFtlSt2rPnVq92ARGjkyq/WkovxPx0DAgMBAAGjggGo
# MIIBpDAfBgNVHSMEGDAWgBQpkWD/ik366/mmarjP+eZLvUnOEjAdBgNVHQ4EFgQU
# wzGKIFk8N4GLg0Ds93yjCBFb1cYwDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQC
# MAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYJYIZIAYb4QgEBBAQDAgQQMEYGA1Ud
# IAQ/MD0wOwYMKwYBBAGyMQECAQMCMCswKQYIKwYBBQUHAgEWHWh0dHBzOi8vc2Vj
# dXJlLmNvbW9kby5uZXQvQ1BTMEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwu
# Y29tb2RvY2EuY29tL0NPTU9ET1JTQUNvZGVTaWduaW5nQ0EuY3JsMHQGCCsGAQUF
# BwEBBGgwZjA+BggrBgEFBQcwAoYyaHR0cDovL2NydC5jb21vZG9jYS5jb20vQ09N
# T0RPUlNBQ29kZVNpZ25pbmdDQS5jcnQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3Nw
# LmNvbW9kb2NhLmNvbTAZBgNVHREEEjAQgQ5oYXVrZUBoYXVrZS51czANBgkqhkiG
# 9w0BAQsFAAOCAQEAVAel6FVu4ytJGBRIphz1LANnymwu/yjbzFvkiQPh4H96TUtE
# tBRNPqIuIRy0JdTQMo3OnN08Xs4cVYQyc74hBZ9D8tst+m1sSvkWSkOuawm3p6Rt
# vfIZLtycmvm6KzgVBsTD9JuRIVypodiPz5QpRuZn5Msc8n3s+XvKAuiGeG0IBGxB
# +hJwT+QE2OTyU01xiw7Kekc3J9qV1SYhXEB+ZFmiivbyKYmfXwTBKX4B1BSh4QBp
# ud5oDgmBzZ+IHE7d7usMRi/5306oABdrf1Vy3r7q+X6KYfj0kJ0Va1tW8DMet7fi
# yFJ7ybsoMd7iW/E0OT6TX04x3MbkcD88SMkUoDCCBeAwggPIoAMCAQICEC58h8wO
# k0pS/pT9HLfNNK8wDQYJKoZIhvcNAQEMBQAwgYUxCzAJBgNVBAYTAkdCMRswGQYD
# VQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNV
# BAoTEUNPTU9ETyBDQSBMaW1pdGVkMSswKQYDVQQDEyJDT01PRE8gUlNBIENlcnRp
# ZmljYXRpb24gQXV0aG9yaXR5MB4XDTEzMDUwOTAwMDAwMFoXDTI4MDUwODIzNTk1
# OVowfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQ
# MA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxIzAh
# BgNVBAMTGkNPTU9ETyBSU0EgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAppiQY3eRNH+K0d3pZzER68we/TEds7liVz+TvFvj
# nx4kMhEna7xRkafPnp4ls1+BqBgPHR4gMA77YXuGCbPj/aJonRwsnb9y4+R1oOU1
# I47Jiu4aDGTH2EKhe7VSA0s6sI4jS0tj4CKUN3vVeZAKFBhRLOb+wRLwHD9hYQqM
# otz2wzCqzSgYdUjBeVoIzbuMVYz31HaQOjNGUHOYXPSFSmsPgN1e1r39qS/AJfX5
# eNeNXxDCRFU8kDwxRstwrgepCuOvwQFvkBoj4l8428YIXUezg0HwLgA3FLkSqnmS
# Us2HD3vYYimkfjC9G7WMcrRI8uPoIfleTGJ5iwIGn3/VCwIDAQABo4IBUTCCAU0w
# HwYDVR0jBBgwFoAUu69+Aj36pvE8hI6t7jiY7NkyMtQwHQYDVR0OBBYEFCmRYP+K
# Tfrr+aZquM/55ku9Sc4SMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/
# AgEAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMBEGA1UdIAQKMAgwBgYEVR0gADBMBgNV
# HR8ERTBDMEGgP6A9hjtodHRwOi8vY3JsLmNvbW9kb2NhLmNvbS9DT01PRE9SU0FD
# ZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDBxBggrBgEFBQcBAQRlMGMwOwYIKwYB
# BQUHMAKGL2h0dHA6Ly9jcnQuY29tb2RvY2EuY29tL0NPTU9ET1JTQUFkZFRydXN0
# Q0EuY3J0MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJ
# KoZIhvcNAQEMBQADggIBAAI/AjnD7vjKO4neDG1NsfFOkk+vwjgsBMzFYxGrCWOv
# q6LXAj/MbxnDPdYaCJT/JdipiKcrEBrgm7EHIhpRHDrU4ekJv+YkdK8eexYxbiPv
# VFEtUgLidQgFTPG3UeFRAMaH9mzuEER2V2rx31hrIapJ1Hw3Tr3/tnVUQBg2V2cR
# zU8C5P7z2vx1F9vst/dlCSNJH0NXg+p+IHdhyE3yu2VNqPeFRQevemknZZApQIvf
# ezpROYyoH3B5rW1CIKLPDGwDjEzNcweU51qOOgS6oqF8H8tjOhWn1BUbp1JHMqn0
# v2RH0aofU04yMHPCb7d4gp1c/0a7ayIdiAv4G6o0pvyM9d1/ZYyMMVcx0DbsR6HP
# y4uo7xwYWMUGd8pLm1GvTAhKeo/io1Lijo7MJuSy2OU4wqjtxoGcNWupWGFKCpe0
# S0K2VZ2+medwbVn4bSoMfxlgXwyaiGwwrFIJkBYb/yud29AgyonqKH4yjhnfe0gz
# Htdl+K7J+IMUk3Z9ZNCOzr41ff9yMU2fnr0ebC+ojwwGUPuMJ7N2yfTm18M04oyH
# IYZh/r9VdOEhdwMKaGy75Mmp5s9ZJet87EUOeWZo6CLNuO+YhU2WETwJitB/vCgo
# E/tqylSNklzNwmWYBp7OSFvUtTeTRkF8B93P+kPvumdh/31J4LswfVyA4+YWOUun
# MYIFgDCCBXwCAQEwgZIwfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIg
# TWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENB
# IExpbWl0ZWQxIzAhBgNVBAMTGkNPTU9ETyBSU0EgQ29kZSBTaWduaW5nIENBAhEA
# 1COFaExESSMmfunez9AKZDAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQULwvCRJWUcB53K8SZG4Un
# Ji14I/swDQYJKoZIhvcNAQEBBQAEggEAP6LcMJt2aICw+DuGktPUeaDnSxfhYoRo
# be0fqhV7lgbcfjP3BPm30bSJJu9HJib1MjK1SFcrmOV5I/rdTADv31GUxpxzKiwb
# 9bSbgoxih9h7fZI/RcrZEwaiZAIBsh8Uc+AUgmbVu2VkARZkr5INSkZw5DRfkVvp
# MAvXoj+OCc1kfiYzRznwFDNltkCMY13WO6vUmYJargAJgNHAyYq3CTnRITIfEDYu
# yu7mCFqXbFpdZBCBvWUtMMxp/xb8BWoxa8PK83ALHA4iDvSIEhbsNkuMBZXoKfJJ
# byLz1PJuKw9u4XGTJey2IzLsnU45bqJvXKxoFKk9kqWtP03JBwq4tqGCA0gwggNE
# BgkqhkiG9w0BCQYxggM1MIIDMQIBATCBkzB+MQswCQYDVQQGEwJQTDEiMCAGA1UE
# ChMZVW5pemV0byBUZWNobm9sb2dpZXMgUy5BLjEnMCUGA1UECxMeQ2VydHVtIENl
# cnRpZmljYXRpb24gQXV0aG9yaXR5MSIwIAYDVQQDExlDZXJ0dW0gVHJ1c3RlZCBO
# ZXR3b3JrIENBAhEA/mfk8Vok48YNVHygIMJ2cDANBglghkgBZQMEAgEFAKCCAXIw
# GgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yMTAz
# MjkxMjA2MjJaMC8GCSqGSIb3DQEJBDEiBCBz5HN9Qs4ldYs5h838g1ub9v7Be70l
# 4X/C8wyZR7BJJzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDZyqvDIltwMM24PjhG
# 42kcFO15CxdkzhtPBDFXiZxcWDCBywYLKoZIhvcNAQkQAgwxgbswgbgwgbUwgbIE
# FE+NTEgGSUJq74uG1NX8eTLnFC2FMIGZMIGDpIGAMH4xCzAJBgNVBAYTAlBMMSIw
# IAYDVQQKExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0
# dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVz
# dGVkIE5ldHdvcmsgQ0ECEQD+Z+TxWiTjxg1UfKAgwnZwMA0GCSqGSIb3DQEBAQUA
# BIIBALrjF7buxOmC7qhZKtDpVXfkZcSsTvWG+4As+l2LVmVE7RmACDlKShZheSaA
# jOV1rrHNlnX5w0NHDyIY1qAWKyk14zSlE/PwRym8AJa0ZoJiAU/S+v+/SHT4i6ih
# 1BwXWz3qBsiI8sh4eL6wMOM82c6L/A1Ls7spZT+yZPESTP+cJ0yGwwGfhCir/yme
# THv/hfNCU2H30DGI6uZrkFC5YOw9CgaGKNCsfxpV/CjsGCl4pzBRzDRTHGTbPviH
# JD6XY5E6EuFuRQ7NuQywNfmXX0eJ74k7rdb/xYSjpNRe3DgODyv89c0aJEE2DNnX
# G2sd6G9kynYGyMQvWiq8QEhBkpk=
# SIG # End signature block
