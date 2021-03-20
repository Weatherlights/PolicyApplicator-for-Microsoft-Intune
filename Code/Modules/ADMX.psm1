﻿
function ConvertTo-ADMXCompatibleName {
    param( $inputobject )
    $inputobject -replace " ", "_" -replace "\.", "_" -replace "__No-Section__", "NoSection" -replace "\[", "_" -replace "\]", "_" -replace "@", "Attribute_" -replace ":",""
}


function ConvertTo-Base64UTF {
    param(
        [string]$Text
    );
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $EncodedText =[Convert]::ToBase64String($Bytes)
    $EncodedText
}


function Get-ADMXPolicyForList {
    param(
        [string]$CategoryName,
        [string]$PolicyName,
        [string]$Class,
        [string]$Key
    );


		$policy = '
<!-- Policy '+$PolicyName+' -->
<policy name="'+$PolicyName+'" class="'+$Class+'" displayName="$(string.Nothing)" explainText="$(string.Nothing)" key="'+$Key+'" valueName="value" >
	<parentCategory ref="'+$CategoryName+'" />
	<supportedOn ref="SupportedOn" />
	<elements>
	<enum id="'+$PolicyName+'-operation" valueName="operation" required="true">
        <item displayName="$(string.Nothing)">
            <value>
                <string>Replace</string>
            </value>
        </item>
    </enum>
		<list id="'+$PolicyName+'-list" key="'+$Key+'\list"/>
	</elements>
</policy>
'

        return $policy;
}

function Get-ADMXPolicyForIni {
    param(
        [string]$CategoryName,
        [string]$PolicyName,
        [string]$Class,
        [string]$Key
    );


		$policy = '
<!-- Policy '+$PolicyName+' -->
<policy name="'+$PolicyName+'" class="'+$Class+'" displayName="$(string.Nothing)" explainText="$(string.Nothing)" key="'+$Key+'" valueName="value" >
	<parentCategory ref="'+$CategoryName+'" />
	<supportedOn ref="SupportedOn" />
	<elements>
	<enum id="'+$PolicyName+'-operation" valueName="operation" required="true">
         <item displayName="$(string.Nothing)">
            <value>
                <string>Create</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>Delete</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>Update</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>Replace</string>
            </value>
        </item>
    </enum>
		<text id="'+$PolicyName+'-section" maxLength="255" valueName="section" required="true"/>
		<text id="'+$PolicyName+'-key" maxLength="255" valueName="key" required="true"/>
		<text id="'+$PolicyName+'-value" maxLength="255" valueName="value" required="true"/>
	</elements>
</policy>
'

        return $policy;
}


function Get-ADMXPolicyForXml {
    param(
        [string]$CategoryName,
        [string]$PolicyName,
        [string]$Class,
        [string]$Key
    );


		$policy = '
<!-- Policy '+$PolicyName+' -->
<policy name="'+$PolicyName+'" class="'+$Class+'" displayName="$(string.Nothing)" explainText="$(string.Nothing)" key="'+$Key+'" valueName="value" >
	<parentCategory ref="'+$CategoryName+'" />
	<supportedOn ref="SupportedOn" />
	<elements>
	<enum id="'+$PolicyName+'-operation" valueName="operation" required="true">
         <item displayName="$(string.Nothing)">
            <value>
                <string>Create</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>Delete</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>Update</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>Replace</string>
            </value>
        </item>
    </enum>
		<list id="'+$PolicyName+'-namespace" key="'+$key+'\namespace"/>
		<text id="'+$PolicyName+'-xpath" maxLength="255" valueName="xpath" required="true"/>
		<text id="'+$PolicyName+'-value" maxLength="255" valueName="value" required="true"/>
	</elements>
</policy>
'

        return $policy;
}



function Get-PolicyRegistryKey {
    param (
        [string]$AppName,
        [string]$AppPolicyName
    );

    $regkeybase = "SOFTWARE\Policies\weatherlights.com\PolicyApplicator\App:$AppName\PolicySet:$AppPolicyName";


    return $regkeybase;
}

function Get-ADMXCategory {
    param(
        [string]$Name,
        [string]$Parent
    );

    $categoryContent = '<category name="'+(ConvertTo-ADMXCompatibleName $Name)+'" displayName="$(string.Nothing)" >
			<parentCategory ref="'+(ConvertTo-ADMXCompatibleName $Parent)+'" />
		</category>'
    
    return $categoryContent;
}

function Get-ADMXTemplate {
    param(
        [string]$AppName,
        [string]$AppPolicyName,
        [string]$Categories,
        [string]$Policies,
        [string]$FileType,
        [string]$Class
    )

    $registryKey = Get-PolicyRegistryKey -AppName $AppName -AppPolicyName $AppPolicyName
    $PolicyName = "$AppName-$AppPolicyName-File"

$ADMXContent = '<?xml version="1.0" encoding="utf-8"?>
<!--
This ADMX-Template has been generated with a PolicyApplicator Applicator Conversion Kit
It is highly recommended that you review the generated content before deploying it.

Note that this template may only work when the PolicyApplicator Client is installed on the target system.
-->
<policyDefinitions xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" revision="1.0" xsi:schemaLocation="" schemaVersion="1.0" xmlns="http://www.microsoft.com/GroupPolicy/PolicyDefinitions" >
	<policyNamespaces >
		<target prefix="' + $AppName + '" namespace="'+$AppName+'.'+ $AppPolicyName +'.Policies" />
	</policyNamespaces>
	<resources minRequiredRevision="1.0" fallbackCulture="en-us" />
	<supportedOn >
		<definitions >
			<definition name="SupportedOn" displayName="$(string.Nothing)" />
		</definitions>
	</supportedOn>
	<categories >'+$categories+'</categories>
    <policies >
    <policy name="'+$PolicyName+'" class="'+$Class+'" displayName="$(string.Nothing)" explainText="$(string.Nothing)" key="'+$registryKey+'" valueName="Mode" >
	<parentCategory ref="'+$AppPolicyName+'" />
	<supportedOn ref="SupportedOn" />
        <enabledValue>
    <string>'+$FileType+'</string>
    </enabledValue>
    <disabledValue>
        <string>Disabled</string>
    </disabledValue>
    <elements>
        <text id="'+$PolicyName+'-path" maxLength="255" valueName="path" required="true"/>
        <boolean id="'+$PolicyName+'-createfile" valueName="CreateFile" >
            <trueValue>
                <decimal value="1" />
            </trueValue>
            <falseValue>
                <decimal value="0" />
            </falseValue>
        </boolean>
         <enum id="'+$PolicyName+'-encoding" valueName="encoding">
         <item displayName="$(string.Nothing)">
            <value>
                <string>utf8</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>utf7</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>unicode</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>bigendianunicode</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>utf32</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>ascii</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>Default</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>OEM</string>
            </value>
        </item>
    </enum>
    </elements>
    </policy>
    '+$policies+'</policies>
</policyDefinitions>';

    return $ADMXContent;
}
# SIG # Begin signature block
# MIIWYAYJKoZIhvcNAQcCoIIWUTCCFk0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUu5TI8w41foN8yHk9gV49vBhM
# yeKgghBKMIIE3DCCA8SgAwIBAgIRAP5n5PFaJOPGDVR8oCDCdnAwDQYJKoZIhvcN
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUSOHPh/bqH8Rg2Q2780Eu
# Ls8Fl74wDQYJKoZIhvcNAQEBBQAEggEAdRT/I1TZ8LhBx4c8aa8PLeGMHXqLZBdP
# p3Xnhc6p8VHbE+yd8zQK2kc2uJ1lLQ7/BUOieyFME/97aKIeBJe6CjooL0GKYI5o
# VUvE0Jj/1vQ+f3lBwJuH1iFzcQwu/D2CtAThyjEw5VrnkIAUcLrLBur/9cqGhGCL
# 4ynRAYQMmFShRRvejCv57/Dij7J/hHLuciGUUzYv8q1jpWAN3MuKp/XNb2jvVbD1
# 0Q3YXafXtZvfr8fSdsfJrK7aDJhaCrBzs6FcXZ3abr3gzTe1JuZh74pYK+ukJGXI
# asKD8vS9Bofkd3leuNUpMVwkcepMPfMH3BjlbTewB4/9RUfEnU0JQ6GCA0gwggNE
# BgkqhkiG9w0BCQYxggM1MIIDMQIBATCBkzB+MQswCQYDVQQGEwJQTDEiMCAGA1UE
# ChMZVW5pemV0byBUZWNobm9sb2dpZXMgUy5BLjEnMCUGA1UECxMeQ2VydHVtIENl
# cnRpZmljYXRpb24gQXV0aG9yaXR5MSIwIAYDVQQDExlDZXJ0dW0gVHJ1c3RlZCBO
# ZXR3b3JrIENBAhEA/mfk8Vok48YNVHygIMJ2cDANBglghkgBZQMEAgEFAKCCAXIw
# GgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yMTAz
# MjAxNjIyMDhaMC8GCSqGSIb3DQEJBDEiBCCnkEbh6NcC089N8ZMV3hpSl4Ptu1q/
# zPVXfvInZtnf+DA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDZyqvDIltwMM24PjhG
# 42kcFO15CxdkzhtPBDFXiZxcWDCBywYLKoZIhvcNAQkQAgwxgbswgbgwgbUwgbIE
# FE+NTEgGSUJq74uG1NX8eTLnFC2FMIGZMIGDpIGAMH4xCzAJBgNVBAYTAlBMMSIw
# IAYDVQQKExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0
# dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVz
# dGVkIE5ldHdvcmsgQ0ECEQD+Z+TxWiTjxg1UfKAgwnZwMA0GCSqGSIb3DQEBAQUA
# BIIBADFqr/DpBZD01F/w0QPp1VlD/hni0vTzZXyq+qadE990l5h1XIp1bSZljDAm
# iFQuy2t7i4NNcVVSL0LAbZ4uqpfsdNQ59r1C79Vp8ofV5xjQ1gKpObbqSNIxpDo4
# btzJCsZ8e/Ang9j/3tz0Pngdk7tbqAZDRUH7cWm55A2RlyMc5ulWCWACL8KoJXQo
# 7Nglpj9SLm30pNF/iRRuRqvd9799ZXPHEvoxZv3mN4gMBYRptVXyiSR4Rw2zSVLI
# bXm+YD0O4LZHIwaZd6M8K6vCmDkbdDbAuLneEk3s8A7VAF1eEYCYoGAp81dfIh6W
# YeTuyOHwz2NX53eAgz2jVHF4Td8=
# SIG # End signature block
