function Test-JSONPathValueOnContent {
<#
.SYNOPSIS
    Tests for an json node value.
.DESCRIPTION
    This function tests an json node for a value. The json node can be selected by providing an JSONPath query.
.PARAMETER Xml
    The json document that you want to evaluate
.PARAMETER XPath
    The json to the node of the json document that you want to evaluate.
.PARAMETER Value
    The value that you want to test against.
.OUTPUTS
    bool
.NOTES
    Created by Hauke Goetze
.LINK
    https://policyapplicator.weatherlights.com
#>
    param(
        $InputObject,
        [Parameter(Mandatory=$True)][string]$JSONPath,
        [string]$Value
    )

    $Nodes = ConvertFrom-Json $JSONPath
     
    $CurrentObject = $InputObject;

    $result = $true;
    $i = 0;

    while ( $result -and ( $i -lt $Nodes.Count ) ) {
        $NodeName = $Nodes[$i];
        $NodeTypePrev = $Nodes[$i].GetType().Name;
        if ( $i -lt $Nodes.Count-1 ) {
            $NodeType = $Nodes[$i+1].getType().Name
        }

        switch ( $NodeTypePrev ) {
            "String"  {
                  if ( !$CurrentObject.$NodeName ) {
                    $result = $false;
                  } else {
                    $CurrentObject = $CurrentObject.$NodeName;
                  }
             }
             "Int32" {
                  if ( !$CurrentObject[$NodeName] ) {
                    $result = $false;
                  } else {
                    $CurrentObject = $CurrentObject[$NodeName];
                  }
             }
         }
         $i++;
    }
    if ( $result ) {
        if ( $CurrentObject -ne $Value ) {
            $result = $false;
        }
    }
    return $result;

}


function Invoke-ParseObjectStructure {
    param(
        $InputObject,
        $CurrentPath
    )
    $OutValue = "";

    $DataType = $InputObject.GetType().Name;
 
    switch ( $InputObject.GetType().Name ) {
       "Object[]" {
            
            For ( $i = 0; $i -lt $InputObject.Count; $i++ ) {
                $NewPath = $CurrentPath + "$i,";
                
                Invoke-ParseObjectStructure -InputObject $InputObject[$i] -CurrentPath $newPath -Elements $Elements
            }
            
        }
        "PSCustomObject" {
            ForEach ( $noteProperty in (Get-Member -InputObject $InputObject | WHERE { $_.MemberType -eq "NoteProperty"} ) ) {           
                $notePropertyName = $noteProperty.Name
                $newPath = $CurrentPath + "`"$notePropertyName`",";
                Invoke-ParseObjectStructure -InputObject $InputObject.$notePropertyName -CurrentPath $newPath -Elements $Elements;
            }
        } default {
            $CurrentPath = $CurrentPath -replace ",$";
            $CurrentPath += "]";
            $FinalPath = $CurrentPath;
            @{
                "Path" = $FinalPath;
                "Value" = $InputObject
            };
        }

   }
}

function Invoke-ParseJSonStructure {
<#
.SYNOPSIS
    Parses a JSON string into a path like structure
.DESCRIPTION
    This function parses a JSON object into a path like structure that can be reassembled with the Set-JSonNodeByJsonPath
.PARAMETER InputObject
    The JSON string you want to translate
.OUTPUTS
    Object[]
.NOTES
    Created by Hauke Goetze
.LINK
    https://policyapplicator.weatherlights.com
#>
    param(
        [string]$InputObject
    )

    $object = ConvertFrom-Json $InputObject

    $Elements = Invoke-ParseObjectStructure -InputObject $object -CurrentPath "[";

    return $Elements

}


function Set-JSonNodeByJsonPath {
    param(
        [Parameter(Mandatory=$True)]$Path, 
        $Value,
        [ValidateSet("Create","Update", "Replace", "Delete")]  
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()][string]$Operation,  
        $InputObject
    )

    $Nodes = ConvertFrom-Json $Path

    # Handle the empty object case
    if ( !$InputObject ) {
        $NodeName = $Nodes[0];
        $NodeType = $Nodes[0].getType().Name
        switch ( $NodeType ) {
            "String"  {
                  $InputObject = @{};
             }
            "Char"  {
                  $InputObject = @{};
             }
             "Int32" {
                $InputObject = [System.Collections.ArrayList]@($null,$null)
             }
             default {
                return $Value;
             }
         }
    }

    $CurrentObject = $InputObject;
    $ObjectToSet = $null;

    # Browse through the structure and build missing elements.
    if ( $Nodes.Count -gt 1 ) {
        For ( $i = 0; $i -lt $Nodes.Count-1; $i++ ) {
            $NodeName = $Nodes[$i];
            $NodeType = $Nodes[$i+1].getType().Name
            if ( !$CurrentObject[$NodeName] ) {
                if  ( $Operation -eq "Create" -or $Operation -eq "Replace" ) {                
                    if ( $CurrentObject.GetType().Name -eq "ArrayList" ) {
                        while ( $CurrentObject.Count -le $NodeName ) {
                            $CurrentObject.Add($null) | Out-Null
                        }
                    }
                    switch ( $NodeType ) {
                        "String"  {
                            $CurrentObject[$NodeName] = @{};
                        }
                        "Int32" {
                            $CurrentObject[$NodeName] = [System.Collections.ArrayList]@()
                        }
                        default {
                            $CurrentObject[$NodeName] = "";
                        }
                    }
                } else {
                    return $InputObject;
                }
            }
           $CurrentObject = $CurrentObject[$NodeName];
           
        }
    } else {
        $i = 0;
    }
    $ObjectToSet = $CurrentObject;

    # Modify the target element
    $NodeName = $Nodes[$i];
    $NodeType = $Nodes[$i].getType().Name
    if ( $Operation -eq "Delete" ) {
        switch ( $objecttoset.GetType().Name ) {
            "ArrayList" {
                $ObjectToSet.RemoveAt($NodeName);
            } default {
                $ObjectToSet.Remove($NodeName);
            }
        }
    } else {
        if ( !$ObjectToSet.$NodeName -or $Operation -eq "Replace" -or $Operation -eq "Update" ) { 
                if ( $ObjectToSet.GetType().Name -eq "ArrayList" ) {
                    while ( $ObjectToSet.Count -le $NodeName ) {
                        $ObjectToSet.Add($null) | Out-Null
                    }
                    
                }
            $ObjectToSet[$NodeName] = $Value;
        }
    }
    return $InputObject
}



function Invoke-JSONRemediation {
<#
.SYNOPSIS
    Detects and remediates missmatches in JSON
.DESCRIPTION
    This function takes a ruleset and matches it against a given json document. If the function runs in remediation mode the json content will be modified according to the ruleset.
.PARAMETER Action
    Defines wether the function will just detect missmatches or remediates them.
.PARAMETER FilePath
    The path to the json file you want to test and remediate.
.PARAMETER Encoding
    The encoding of the json file in case it needs to be created.
.PARAMETER Rules
    The set of remediation rules you want to match against the json document.
.PARAMETER Operation
    Specifies what you want to do with the selected file (Create, update or replace).
.NOTES
    Created by Hauke Goetze
.LINK
    https://policyapplicator.weatherlights.com
#>
param (
        [ValidateSet("Detect","Remediate")]  
        [Parameter()]  
        [string]$Action = "Detect",  


        [ValidateNotNullOrEmpty()]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$FilePath,

        [ValidateSet("Unicode","UTF7","UTF8","UTF32","ASCII","BigEndianUnicode","Default","OEM")]  
        [Parameter()]  
        [string]$Encoding = "Unicode", 

        [ValidateNotNullOrEmpty()][Parameter(Mandatory=$True)][System.Array]$Rules,

        [ValidateSet("create","update","replace")][string]$Operation = "create"

);
    $Compliance = "Compliant";
    $fileDoesNotExistYet = $false;
    $newJsonObj = $null;

    #try {
            if ( Test-Path -Path $FilePath ) {
                $encoding = Get-FileEncoding -Path $FilePath;
                $json = Get-Content -Path $FilePath -Encoding $encoding -Raw
                $jsonobj = ConvertFrom-Json $json;

                forEach ( $rule in $Rules ) {
                    if ( !(Test-JSONPathValueOnContent -InputObject $jsonobj -JsonPath $rule.JSONPath -Value $rule.Value) ) {
                        $Compliance = "Non-Compliant: Element missmatch!"
                    }
                }

            } else {
                $jsonobj;
                $fileDoesNotExistYet = $true;

                $Compliance = "Non-Compliant: File does not exist!"
            }
            

            if ( $Compliance -ne "Compliant" ) {
                switch ( $Operation ) {
                    "Create" {
                    # In case the file exist merge it with the ruleset.
                        if ( !$fileDoesNotExistYet ) {
                            $RecreateFileRules = Invoke-ParseJSonStructure -InputObject $json;
                            ForEach ( $rule in $RecreateFileRules ) {
                                
                                $newJsonObj = Set-JSonNodeByJsonPath -Path $rule.Path -InputObject $newJsonObj -Value $rule.Value -Operation Create;
                            }
                        }
                        ForEach ( $rule in $Rules ) {
                            $ruleValueAsDataType = Convert-StringToJsonDataType -InputObject $rule.Value -DataType $rule.DataType;
                            $newJsonObj = Set-JSonNodeByJsonPath -InputObject $newJsonObj -Path $rule.JSONPath -value $ruleValueAsDataType -Operation $rule.Operation;
                        }

                    }
                    "Replace" {
                    # Recreate file from scratch.
                        ForEach ( $rule in $Rules ) {
                            $ruleValueAsDataType = Convert-StringToJsonDataType -InputObject $rule.Value -DataType $rule.DataType;
                            $newJsonObj = Set-JSonNodeByJsonPath -InputObject $newJsonObj -Path $rule.JSONPath -value $ruleValueAsDataType -Operation $rule.Operation;
                        }
                        
                    }
                    "Update" {
                    # Only modify anything if the file already exists.
                        if ( !$fileDoesNotExistYet ) {
                            $RecreateFileRules = Invoke-ParseJSonStructure -InputObject $json;
                            ForEach ( $rule in $RecreateFileRules ) {
                                $newJsonObj = Set-JSonNodeByJsonPath -Path $rule.Path -InputObject $newJsonObj -Value $rule.Value -Operation Create;
                            }
                            ForEach ( $rule in $Rules ) {
                                $ruleValueAsDataType = Convert-StringToJsonDataType -InputObject $rule.Value -DataType $rule.DataType;
                                $newJsonObj = Set-JSonNodeByJsonPath -InputObject $newJsonObj -Path $rule.JSONPath -value $ruleValueAsDataType -Operation $rule.Operation;
                            }
                        }
                    }
                }

                if ( $newJsonObj -and $Action -eq "Remediate" ) {
                    # Create the path to the file in case it does not exist
                    if ( !(Test-Path -Path "$Filepath\..") ) {
                        New-Item -Path $Filepath\.. -ItemType Directory
                    }
                    # Write the new json file to disk.
                    Out-File -FilePath $FilePath -InputObject (ConvertTo-Json $newJsonObj -Depth 99) -Encoding $encoding -Force
                    # Reset compliance state since everything has been remediated.
                    $Compliance = "Compliant"
                }
            }

      #  } catch {
       #     Write-Host "OHOH!"
      #          $compliance = "Non-Compliant: Unknown error occured"
       # }
       return $Compliance
}

function Convert-StringToJsonDataType {
param(
    [string]$InputObject,
    [ValidateSet("Boolean","Int32","String","Decimal")][string]$DataType
)

    if ( $DataType -eq "Boolean" ) {
        if ( $InputObject -eq "True" ) {
            return $true;
        } elseif ( $InputObject -eq "False" ) {
            return $false;
        }
        else {
            throw "Invalid Input format"
        }
    } elseif ( $DataType -eq "Int32" ) {
        return [Int32]$InputObject
    }  elseif ( $DataType -eq "Decimal" ) {
        return [Decimal]$InputObject
    } else {
        return $InputObject;
    }
}

# Set-AuthenticodeSignature "$env:userprofile\GitHub\PolicyApplicator-for-Microsoft-Intune\Code\Modules\JSONFile.psm1" @(Get-ChildItem cert:\CurrentUser\My -codesigning)[0] -TimestampServer http://time.certum.pl
# SIG # Begin signature block
# MIIlHAYJKoZIhvcNAQcCoIIlDTCCJQkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBMb+6jcnIXGCPn
# g+jI7josRcJL/fz81K6Cac/aMyT5maCCHikwggUJMIID8aADAgECAhANqkyYTw1Q
# okNvjhyldPdwMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# ExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoT
# D1NlY3RpZ28gTGltaXRlZDEkMCIGA1UEAxMbU2VjdGlnbyBSU0EgQ29kZSBTaWdu
# aW5nIENBMB4XDTIxMDQyMDAwMDAwMFoXDTI0MDQxOTIzNTk1OVowVjELMAkGA1UE
# BhMCREUxGzAZBgNVBAgMElNjaGxlc3dpZy1Ib2xzdGVpbjEUMBIGA1UECgwLSGF1
# a2UgR290emUxFDASBgNVBAMMC0hhdWtlIEdvdHplMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEA2rojdl5057Y5VDv9PzmzdU/pQXhtE0PSD7tpp7md4odE
# WXfslWg1gGqBpv3scwSIdzzonMZ2Vu3Faz+54+dQ1Up2UZEJfvuRmSyN5SPi5bDq
# PuUjdf7chfyZipz28/haWL/IAZ6KFMByTmmPEzFYtfnD8PaxfrRHURp/B91tmNe/
# h4pHNE0DFCaXGFx38pUXfoFRoQlcFJATqvKBvB3CN6wKBLmTRg37ofhYWrj/Ca2+
# qJrgP2DaRQiEc68JE+6nE/6UYhh7d1pRiA0uuotkInOtvYQo5fS8fQrESvF8a6mJ
# xHfYiFeivk6nVCQGDUn+wS8XbZ15fQ10rjxs/quD3QIDAQABo4IBqzCCAacwHwYD
# VR0jBBgwFoAUDuE6qFM6MdWKvsG7rWcaA4WtNA4wHQYDVR0OBBYEFK7W1Lj6n3wl
# xTtMGDE88E5Hvj5QMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMBEGCWCGSAGG+EIBAQQEAwIEEDBKBgNVHSAEQzBBMDUG
# DCsGAQQBsjEBAgEDAjAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29t
# L0NQUzAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5zZWN0
# aWdvLmNvbS9TZWN0aWdvUlNBQ29kZVNpZ25pbmdDQS5jcmwwcwYIKwYBBQUHAQEE
# ZzBlMD4GCCsGAQUFBzAChjJodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29S
# U0FDb2RlU2lnbmluZ0NBLmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2Vj
# dGlnby5jb20wGQYDVR0RBBIwEIEOaGF1a2VAaGF1a2UudXMwDQYJKoZIhvcNAQEL
# BQADggEBACdP4v3woMgxxLWaD8dVjawH9rET5JX9mv8vGNyfF3dXL3a9msRqiqjp
# HQbLtK1Q3TxR62eB5+juL+kFxP0d/XsW8QNzVM19DaCYsEloOwC86TD1whcaMQXr
# KgsOa36vFUKohjGxnYWHQtjyCu6iEvjQvd//e06tCeuOTcEprx9ipXWK/USMwjCA
# w7hdeaHvF6ZW6aAfOu+ItPD/3VsObCszzFnHFIHf4iBfcpT9u6+NkULR41k3kOyl
# DT4BBh6gMgnwjIECBZkG77V31FtlWxn9NTzrArw7K2EqLZEpmd6oAsTtoDN8Vux3
# w2cB/bJ4mb0wq6Yv8eeJCjIIPFGUOEswggXJMIIEsaADAgECAhAbtY8lKt8jAEko
# ya49fu0nMA0GCSqGSIb3DQEBDAUAMH4xCzAJBgNVBAYTAlBMMSIwIAYDVQQKExlV
# bml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2VydGlm
# aWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVzdGVkIE5ldHdv
# cmsgQ0EwHhcNMjEwNTMxMDY0MzA2WhcNMjkwOTE3MDY0MzA2WjCBgDELMAkGA1UE
# BhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAlBgNV
# BAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMbQ2Vy
# dHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAvfl4+ObVgAxknYYblmRnPyI6HnUBfe/7XGeMycxca6mR5rlC5SBL
# m9qbe7mZXdmbgEvXhEArJ9PoujC7Pgkap0mV7ytAJMKXx6fumyXvqAoAl4Vaqp3c
# KcniNQfrcE1K1sGzVrihQTib0fsxf4/gX+GxPw+OFklg1waNGPmqJhCrKtPQ0WeN
# G0a+RzDVLnLRxWPa52N5RH5LYySJhi40PylMUosqp8DikSiJucBb+R3Z5yet/5oC
# l8HGUJKbAiy9qbk0WQq/hEr/3/6zn+vZnuCYI+yma3cWKtvMrTscpIfcRnNeGWJo
# RVfkkIJCu0LW8GHgwaM9ZqNd9BjuiMmNF0UpmTJ1AjHuKSbIawLmtWJFfzcVWiNo
# idQ+3k4nsPBADLxNF8tNorMe0AZa3faTz1d1mfX6hhpneLO/lv403L3nUlbls+V1
# e9dBkQXcXWnjlQ1DufyDljmVe2yAWk8TcsbXfSl6RLpSpCrVQUYJIP4ioLZbMI28
# iQzV13D4h1L92u+sUS4Hs07+0AnacO+Y+lbmbdu1V0vc5SwlFcieLnhO+NqcnoYs
# ylfzGuXIkosagpZ6w7xQEmnYDlpGizrrJvojybawgb5CAKT41v4wLsfSRvbljnX9
# 8sy50IdbzAYQYLuDNbdeZ95H7JlI8aShFf6tjGKOOVVPORa5sWOd/7cCAwEAAaOC
# AT4wggE6MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLahVDkCw6A/joq8+tT4
# HKbROg79MB8GA1UdIwQYMBaAFAh2zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1UdDwEB
# /wQEAwIBBjAvBgNVHR8EKDAmMCSgIqAghh5odHRwOi8vY3JsLmNlcnR1bS5wbC9j
# dG5jYS5jcmwwawYIKwYBBQUHAQEEXzBdMCgGCCsGAQUFBzABhhxodHRwOi8vc3Vi
# Y2Eub2NzcC1jZXJ0dW0uY29tMDEGCCsGAQUFBzAChiVodHRwOi8vcmVwb3NpdG9y
# eS5jZXJ0dW0ucGwvY3RuY2EuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQGCCsG
# AQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEMBQAD
# ggEBAFHCoVgWIhCL/IYx1MIy01z4S6Ivaj5N+KsIHu3V6PrnCA3st8YeDrJ1BXqx
# C/rXdGoABh+kzqrya33YEcARCNQOTWHFOqj6seHjmOriY/1B9ZN9DbxdkjuRmmW6
# 0F9MvkyNaAMQFtXx0ASKhTP5N+dbLiZpQjy6zbzUeulNndrnQ/tjUoCFBMQllVXw
# fqefAcVbKPjgzoZwpic7Ofs4LphTZSJ1Ldf23SIikZbr3WjtP6MZl9M7JYjsNhI9
# qX7OAo0FmpKnJ25FspxihjcNpDOO16hO0EoXQ0zF8ads0h5YbBRRfopUofbvn3l6
# XYGaFpAP4bvxSgD5+d2+7arszgowggX1MIID3aADAgECAhAdokgwb5smGNCC4JZ9
# M9NqMA0GCSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eTAeFw0xODExMDIwMDAwMDBaFw0zMDEyMzEyMzU5NTlaMHwx
# CzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNV
# BAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEkMCIGA1UEAxMb
# U2VjdGlnbyBSU0EgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEAhiKNMoV6GJ9J8JYvYwgeLdx8nxTP4ya2JWYpQIZURnQxYsUQ
# 7bKHJ6aZy5UwwFb1pHXGqQ5QYqVRkRBq4Etirv3w+Bisp//uLjMg+gwZiahse60A
# w2Gh3GllbR9uJ5bXl1GGpvQn5Xxqi5UeW2DVftcWkpwAL2j3l+1qcr44O2Pej79u
# TEFdEiAIWeg5zY/S1s8GtFcFtk6hPldrH5i8xGLWGwuNx2YbSp+dgcRyQLXiX+8L
# Rf+jzhemLVWwt7C8VGqdvI1WU8bwunlQSSz3A7n+L2U18iLqLAevRtn5RhzcjHxx
# KPP+p8YU3VWRbooRDd8GJJV9D6ehfDrahjVh0wIDAQABo4IBZDCCAWAwHwYDVR0j
# BBgwFoAUU3m/WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFA7hOqhTOjHVir7B
# u61nGgOFrTQOMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMB0G
# A1UdJQQWMBQGCCsGAQUFBwMDBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAw
# UAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJU
# cnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHYGCCsGAQUFBwEBBGow
# aDA/BggrBgEFBQcwAoYzaHR0cDovL2NydC51c2VydHJ1c3QuY29tL1VTRVJUcnVz
# dFJTQUFkZFRydXN0Q0EuY3J0MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2Vy
# dHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBNY1DtRzRKYaTb3moqjJvxAAAe
# HWJ7Otcywvaz4GOz+2EAiJobbRAHBE++uOqJeCLrD0bs80ZeQEaJEvQLd1qcKkE6
# /Nb06+f3FZUzw6GDKLfeL+SU94Uzgy1KQEi/msJPSrGPJPSzgTfTt2SwpiNqWWhS
# Ql//BOvhdGV5CPWpk95rcUCZlrp48bnI4sMIFrGrY1rIFYBtdF5KdX6luMNstc/f
# SnmHXMdATWM19jDTz7UKDgsEf6BLrrujpdCEAJM+U100pQA1aWy+nyAlEA0Z+1CQ
# Yb45j3qOTfafDh7+B1ESZoMmGUiVzkrJwX/zOgWb+W/fiH/AI57SHkN6RTHBnE2p
# 8FmyWRnoao0pBAJ3fEtLzXC+OrJVWng+vLtvAxAldxU0ivk2zEOS5LpP8WKTKCVX
# KftRGcehJUBqhFfGsp2xvBwK2nxnfn0u6ShMGH7EezFBcZpLKewLPVdQ0srd/Z4F
# UeVEeN0B3rF1mA1UJP3wTuPi+IO9crrLPTru8F4XkmhtyGH5pvEqCgulufSe7pgy
# BYWe6/mDKdPGLH29OncuizdCoGqC7TtKqpQQpOEN+BfFtlp5MxiS47V1+KHpjgol
# HuQe8Z9ahyP/n6RRnvs5gBHN27XEp6iAb+VT1ODjosLSWxr6MiYtaldwHDykWC6j
# 81tLB9wyWfOHpxptWDCCBpUwggR9oAMCAQICEAnFzPi7Zn1xN6rBWYAGyzEwDQYJ
# KoZIhvcNAQEMBQAwVjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRh
# IFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIx
# IENBMB4XDTIzMTEwMjA4MzIyM1oXDTM0MTAzMDA4MzIyM1owUDELMAkGA1UEBhMC
# UEwxITAfBgNVBAoMGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEeMBwGA1UEAwwV
# Q2VydHVtIFRpbWVzdGFtcCAyMDIzMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAuRa66sbnfZI2qoJAKPOSMrennDd+Nzlj87TThZDkb7HOrpIbnDjkEPrM
# 8R9I7ItwEYwcBtW/aEMJw8dQjjpDqcJth82Ns8bSXtl9qgvh/AzLePp1DQGBbjBD
# I0XquabQ0yNyYnQxG4HMSna9ms3wsJidxaahqSq9S27Qg9mO4i68GTsTg5HVWChM
# iS9FDydgNfCYDUeePgmdP6VXwn2zhGWoOuaMlNwN92WPPIeZoc5/ViDxf6i0earf
# RynvbvGPrjIM/DCkGoB/2o1hv7mHKnkCtvAEtxIeQHEsJeMRX8BxmhcBMcQVkly2
# URlG5/WhXYq0mSinXttKdQjpZmZMSJiWPm8UGEoMOZxDNIz4Oq3jw/tCEEHOADyu
# nUhwDkEt0LwSa3801pQkKJBrTr8XDSLOXDr2gDZk3BnC4JB9Hh4DAaSxZXMsxNEJ
# GPB3ofsZbWRRIgLyuYG5/Ah7PKKPaNPyYy6nVmC61uB5xEuN/zQtf7DmglZrbJU2
# haFv1kUW7SWkayv9N4xY6zfdtXQp7UUYpwfxMNzENZMTzetOFgjHi7wDqU9xeSmw
# V6Dw6zKFvThk2J2Kr/PAOoU21RUbPhIvFCY5OCJXzpJx1nbopkSkOC2A2NRg0gN9
# 2FGf3Nz6KLWp3NoljzWr48v4ng2CHR/F1W0X1qnIZw6UxPtDRXMCAwEAAaOCAWMw
# ggFfMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFMdpPC7mveNZR/8ZEsHZNOhBz+OP
# MB8GA1UdIwQYMBaAFL5UAi+/QGxzQ86sCSVOnkNEGu7gMA4GA1UdDwEB/wQEAwIH
# gDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAzBgNVHR8ELDAqMCigJqAkhiJodHRw
# Oi8vY3JsLmNlcnR1bS5wbC9jdHNjYTIwMjEuY3JsMG8GCCsGAQUFBwEBBGMwYTAo
# BggrBgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTA1BggrBgEF
# BQcwAoYpaHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBsL2N0c2NhMjAyMS5jZXIw
# QQYDVR0gBDowODA2BgsqhGgBhvZ3AgUBCzAnMCUGCCsGAQUFBwIBFhlodHRwczov
# L3d3dy5jZXJ0dW0ucGwvQ1BTMA0GCSqGSIb3DQEBDAUAA4ICAQB43e6xOkPm99lr
# OL0yXgtB3Bg4u5n0FJ22ifZxRTkKYsz1/mCKR7ivPUz5DnQxe5ThJk2c1UKcNJMK
# SGQ7gfJUjNBsPSpaDr1yLBoxfyoEzcWDOWlYkDTLaCIhelvcrJrmwxxe5RMUk6D3
# da/jdM2Bl5RNbhF+KPfPCv2e5MIBPxguuPUtThGeSBkhpoq7XK7i1/8YYyAwOUv3
# FX89FnvxJR2ph7PlH1t/yMU4oL76uCQm3WR4PQ7I5FvlIBhgFbZMQe6op5liWpr3
# cKYLowMDk9cpv4Ij01uQvPzJ5C9fGYFUN/LKiqhXalEvmSFXlyn1efB2lrVdi4qd
# WNJbi+zLMG/Oeo8+81yDZO/R+F321jq8n+wLVgY67rNvI5h1it4FzYY9krVXDiOP
# A3OghX1wzKP3PxP2m9te5E2IYobdqwlnhkuUx0N22VcfpVDy2g3t5FV42L8TGECl
# rtOEF+vr1ERUni91la1EjupxJ2bu19hGHIuTFJplHRBIgFWTv9N8i5TVlDRl+9v/
# ePb1PuWTfa/RBnae191u5iy9U8eIC5h56wfezvnvUWCut+9DAudrIrn7tdad5/Dh
# ubNsycNiei6Q/hy28goH0SHfUOVCoLI9ANULqAbrfBSOmHWh97EdaaJxL+hrDWK0
# 8gbUke+3LFFi1AslW6LBd/mntPkqHzCCBrkwggShoAMCAQICEQDn/2nHOzXOS5Em
# 2HR8aKWHMA0GCSqGSIb3DQEBDAUAMIGAMQswCQYDVQQGEwJQTDEiMCAGA1UEChMZ
# VW5pemV0byBUZWNobm9sb2dpZXMgUy5BLjEnMCUGA1UECxMeQ2VydHVtIENlcnRp
# ZmljYXRpb24gQXV0aG9yaXR5MSQwIgYDVQQDExtDZXJ0dW0gVHJ1c3RlZCBOZXR3
# b3JrIENBIDIwHhcNMjEwNTE5MDUzMjA3WhcNMzYwNTE4MDUzMjA3WjBWMQswCQYD
# VQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYD
# VQQDExtDZXJ0dW0gVGltZXN0YW1waW5nIDIwMjEgQ0EwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDpEh8ENe25XXrFppVBvoplf0530W0lddNmjtv4YSh/
# f7eDQKFaIqc7tHj7ox+u8vIsJZlroakUeMS3i3T8aJRC+eQs4FF0GqvkM6+WZO8k
# mzZfxmZaBYmMLs8FktgFYCzywmXeQ1fEExflee2OpbHVk665eXRHjH7MYZIzNnjl
# 2m8Hy8ulB9mR8wL/W0v0pjKNT6G0sfrx1kk+3OGosFUb7yWNnVkWKU4qSxLv16kJ
# 6oVJ4BSbZ4xMak6JLeB8szrK9vwGDpvGDnKCUMYL3NuviwH1x4gZG0JAXU3x2pOA
# z91JWKJSAmRy/l0s0l5bEYKolg+DMqVhlOANd8Yh5mkQWaMEvBRE/kAGzIqgWhwz
# N2OsKIVtO8mf5sPWSrvyplSABAYa13rMYnzwfg08nljZHghquCJYCa/xHK9acev9
# UD7Y+usr15d7mrszzxhF1JOr1Mpup2chNSBlyOObhlSO16rwrffVrg/SzaKfSndS
# 5swRhr8bnDqNJY9TNyEYvBYpgF95K7p0g4LguR4A++Z1nFIHWVY5v0fNVZmgzxD9
# uVo/gta3onGOQj3JCxgYx0KrCXu4yc9QiVwTFLWbNdHFSjBCt5/8Q9pLuRhVocdC
# unhcHudMS1CGQ/Rn0+7P+fzMgWdRKfEOh/hjLrnQ8BdJiYrZNxvIOhM2aa3zEDHN
# wwIDAQABo4IBVTCCAVEwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUvlQCL79A
# bHNDzqwJJU6eQ0Qa7uAwHwYDVR0jBBgwFoAUtqFUOQLDoD+Oirz61PgcptE6Dv0w
# DgYDVR0PAQH/BAQDAgEGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMDAGA1UdHwQpMCcw
# JaAjoCGGH2h0dHA6Ly9jcmwuY2VydHVtLnBsL2N0bmNhMi5jcmwwbAYIKwYBBQUH
# AQEEYDBeMCgGCCsGAQUFBzABhhxodHRwOi8vc3ViY2Eub2NzcC1jZXJ0dW0uY29t
# MDIGCCsGAQUFBzAChiZodHRwOi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3RuY2Ey
# LmNlcjA5BgNVHSAEMjAwMC4GBFUdIAAwJjAkBggrBgEFBQcCARYYaHR0cDovL3d3
# dy5jZXJ0dW0ucGwvQ1BTMA0GCSqGSIb3DQEBDAUAA4ICAQC4k1l3yUwV/ZQHCKCn
# eqAs8EGTnwEUJLdDpokN/dMhKjK0rR5qX8nIIHzxpQR3TAw2IRw1Uxsr2PliG3bC
# FqSdQTUbfaTq6V3vBzEebDru9QFjqlKnxCF2h1jhLNFFplbPJiW+JSnJTh1fKEqE
# dKdxgl9rVTvlxfEJ7exOn25MGbd/wGPwuSmMxRJVO0wnqgS7kmoJjNF9zqeehFSD
# DP8ZVkWg4EZ2tIS0M3uZmByRr+1Lkwjjt8AtW83mVnZTyTsOb+FNfwJY7DS4FmWh
# kRbgcHRetreoTirPOr/ozyDKhT8MTSTf6Lttg6s6T/u08mDWw6HK04ZRDfQ9sb77
# QV8mKgO44WGP31vXnVKoWVJpFBjPvjL8/Zck/5wXX2iqjOaLStFOR/IQki+Ehn4z
# lcgVm22ZVCBPF+l8nAwUUShCtKuSU7GmZLKCmmxQMkSiWILTm8EtVD6AxnJhoq8E
# nhjEEyUoflkeRF2WhFiVQOmWTwZRr44IxWGkNJC6tTorW5rl2Zl+2e9JLPYf3pSt
# APMDoPKIjVXd6NW2+fZrNUBeDo2eOa5Fn7Brs/HLQff5Xgris5MeUbdVgDrF8uxO
# 6cLPvZPo63j62SsNg55pTWk9fUIF9iPoRbb4QurjoY/woI1RAOKtYtTic6aAJq3u
# 83RIPpGXBSJKwx4KJAOZnCDCtTGCBkkwggZFAgEBMIGQMHwxCzAJBgNVBAYTAkdC
# MRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQx
# GDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEkMCIGA1UEAxMbU2VjdGlnbyBSU0Eg
# Q29kZSBTaWduaW5nIENBAhANqkyYTw1QokNvjhyldPdwMA0GCWCGSAFlAwQCAQUA
# oIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcN
# AQkEMSIEIAo4j38FxscDCVKKle2uXqximlMzy/6Zo7iHxEnv5vAjMA0GCSqGSIb3
# DQEBAQUABIIBAMMLqYNXh724/vJPKnqBdTW3YBTfGb2ct+ErA48O8tovYwKVsz5j
# nd8AQP8n2JUKr1LeGMREjYOL7AVGO88rj1mZo+NwZ16HMHllQ7+qsBpg9YeA6qk8
# FxzJq/LEBI4566cT1SoNoqRiH5vuazXOOoul7eqqv/kQ1FOW/AkH/uYN8Z3t1jsJ
# vLGjz9anN8uUGVJPFNNIiwoEE5nGXvZHQTKv2pbl0JvBoIfqp64oem4MaOmakXco
# Iee0YJdHP8XKQt4HHVPt6zWCrrtfsB7L742AWBwcxovuo877ZMPREfeLU4itCGJu
# LwGVUx0CSBMhwUu2KkJyQFbnF4OlMWgpxaahggQCMIID/gYJKoZIhvcNAQkGMYID
# 7zCCA+sCAQEwajBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEg
# U3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0YW1waW5nIDIwMjEg
# Q0ECEAnFzPi7Zn1xN6rBWYAGyzEwDQYJYIZIAWUDBAICBQCgggFWMBoGCSqGSIb3
# DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjQwMzA3MjI1NDM4
# WjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDqlUux0EC0MUBI2GWfj2FdiHQszOBn
# kuBWAk1LADrTHDA/BgkqhkiG9w0BCQQxMgQw2Qg/iyEiKBqIkNbMJw3h4hTsRfcQ
# fr5tNLJvoBCoptNJTPMVHPN9JC/Gf8JOAumaMIGfBgsqhkiG9w0BCRACDDGBjzCB
# jDCBiTCBhgQUD0+4VR7/2Pbef2cmtDwT0Gql53cwbjBapFgwVjELMAkGA1UEBhMC
# UEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMb
# Q2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhAJxcz4u2Z9cTeqwVmABssxMA0G
# CSqGSIb3DQEBAQUABIICAExnMNnODTENH3xsQRAOMdgcyZTDFVYvC3gr6kU+wKAm
# KzTl3vTcrHC5ZU6N73BBP7KY2PiMucJOtxNFvedfuFcDoY+t+rvxtW2ftBDBU//s
# UMsvByB/3toYkek9EPjTJMedQB8dS3sEg9fF7DinJj97f4Kg7a8hJj25PFm0FlTN
# G2t2nBI3vi5sqK+ZoesG0xscABZ+DUNoBRoWPcuR0rz2f+WNIM9OIhSwq9wzHY/2
# JqwzPGG8gdWGLootrUpBv9GiBZQ2ngD/5/VGQ7VKMEflRJiDFGhXEuNvH6WqL4Tg
# CtIbOLqF8SZtjXkkIw0kYVPXJgXLnt/naP+6EVk5q6lLuQ/qdZU00EsaecSfCLeZ
# 4LH0YZLARciMRupITllfq2KiqqDbtJAL6PGOqHL+fabJmlGpqZtVv3k6xoQJF88k
# fyMp065SQpqd+EDVdn8B413VXr2Jp94g2ojtfnIXgPtbs9Tek7dagUH+Ac2TdwlE
# CK9AmjF9ruq+OoQ02Aztz7gJT4eQxCtiOkI1avJ3ks5vhINLTZRZ7Bj2sxR0ZQoH
# nCMAlYiCb36C7AE31iKw2J/yatJVO1T7iP+kmSzakmh1UrEvNRBzHObzzUaM3omx
# E5SnTpySFZYewF0iU6v52AHVrJh+qFOt3TdbOJEUNC4VIFQ+jborfIboWNawnw8y
# SIG # End signature block
