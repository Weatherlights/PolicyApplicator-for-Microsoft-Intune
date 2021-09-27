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
    [ValidateSet("Boolean","Int32","String")][string]$DataType
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
    } else {
        return $InputObject;
    }
}

# Set-AuthenticodeSignature "$env:userprofile\GitHub\PolicyApplicator-for-Microsoft-Intune\Code\Modules\JSONFile.psm1" @(Get-ChildItem cert:\CurrentUser\My -codesigning)[0] -TimestampServer http://time.certum.pl
# SIG # Begin signature block
# MIIk+QYJKoZIhvcNAQcCoIIk6jCCJOYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU54hOuR2BzGpO7tq60xjssktz
# sV+ggh4pMIIFCTCCA/GgAwIBAgIQDapMmE8NUKJDb44cpXT3cDANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJDAi
# BgNVBAMTG1NlY3RpZ28gUlNBIENvZGUgU2lnbmluZyBDQTAeFw0yMTA0MjAwMDAw
# MDBaFw0yNDA0MTkyMzU5NTlaMFYxCzAJBgNVBAYTAkRFMRswGQYDVQQIDBJTY2hs
# ZXN3aWctSG9sc3RlaW4xFDASBgNVBAoMC0hhdWtlIEdvdHplMRQwEgYDVQQDDAtI
# YXVrZSBHb3R6ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANq6I3Ze
# dOe2OVQ7/T85s3VP6UF4bRND0g+7aae5neKHRFl37JVoNYBqgab97HMEiHc86JzG
# dlbtxWs/uePnUNVKdlGRCX77kZksjeUj4uWw6j7lI3X+3IX8mYqc9vP4Wli/yAGe
# ihTAck5pjxMxWLX5w/D2sX60R1EafwfdbZjXv4eKRzRNAxQmlxhcd/KVF36BUaEJ
# XBSQE6rygbwdwjesCgS5k0YN+6H4WFq4/wmtvqia4D9g2kUIhHOvCRPupxP+lGIY
# e3daUYgNLrqLZCJzrb2EKOX0vH0KxErxfGupicR32IhXor5Op1QkBg1J/sEvF22d
# eX0NdK48bP6rg90CAwEAAaOCAaswggGnMB8GA1UdIwQYMBaAFA7hOqhTOjHVir7B
# u61nGgOFrTQOMB0GA1UdDgQWBBSu1tS4+p98JcU7TBgxPPBOR74+UDAOBgNVHQ8B
# Af8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzARBglg
# hkgBhvhCAQEEBAMCBBAwSgYDVR0gBEMwQTA1BgwrBgEEAbIxAQIBAwIwJTAjBggr
# BgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQBMEMGA1Ud
# HwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1JTQUNv
# ZGVTaWduaW5nQ0EuY3JsMHMGCCsGAQUFBwEBBGcwZTA+BggrBgEFBQcwAoYyaHR0
# cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUlNBQ29kZVNpZ25pbmdDQS5jcnQw
# IwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMBkGA1UdEQQSMBCB
# DmhhdWtlQGhhdWtlLnVzMA0GCSqGSIb3DQEBCwUAA4IBAQAnT+L98KDIMcS1mg/H
# VY2sB/axE+SV/Zr/Lxjcnxd3Vy92vZrEaoqo6R0Gy7StUN08Uetngefo7i/pBcT9
# Hf17FvEDc1TNfQ2gmLBJaDsAvOkw9cIXGjEF6yoLDmt+rxVCqIYxsZ2Fh0LY8gru
# ohL40L3f/3tOrQnrjk3BKa8fYqV1iv1EjMIwgMO4XXmh7xemVumgHzrviLTw/91b
# DmwrM8xZxxSB3+IgX3KU/buvjZFC0eNZN5DspQ0+AQYeoDIJ8IyBAgWZBu+1d9Rb
# ZVsZ/TU86wK8OythKi2RKZneqALE7aAzfFbsd8NnAf2yeJm9MKumL/HniQoyCDxR
# lDhLMIIFyTCCBLGgAwIBAgIQG7WPJSrfIwBJKMmuPX7tJzANBgkqhkiG9w0BAQwF
# ADB+MQswCQYDVQQGEwJQTDEiMCAGA1UEChMZVW5pemV0byBUZWNobm9sb2dpZXMg
# Uy5BLjEnMCUGA1UECxMeQ2VydHVtIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MSIw
# IAYDVQQDExlDZXJ0dW0gVHJ1c3RlZCBOZXR3b3JrIENBMB4XDTIxMDUzMTA2NDMw
# NloXDTI5MDkxNzA2NDMwNlowgYAxCzAJBgNVBAYTAlBMMSIwIAYDVQQKExlVbml6
# ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkxJDAiBgNVBAMTG0NlcnR1bSBUcnVzdGVkIE5ldHdvcmsg
# Q0EgMjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL35ePjm1YAMZJ2G
# G5ZkZz8iOh51AX3v+1xnjMnMXGupkea5QuUgS5vam3u5mV3Zm4BL14RAKyfT6Low
# uz4JGqdJle8rQCTCl8en7psl76gKAJeFWqqd3CnJ4jUH63BNStbBs1a4oUE4m9H7
# MX+P4F/hsT8PjhZJYNcGjRj5qiYQqyrT0NFnjRtGvkcw1S5y0cVj2udjeUR+S2Mk
# iYYuND8pTFKLKqfA4pEoibnAW/kd2ecnrf+aApfBxlCSmwIsvam5NFkKv4RK/9/+
# s5/r2Z7gmCPspmt3FirbzK07HKSH3EZzXhliaEVX5JCCQrtC1vBh4MGjPWajXfQY
# 7ojJjRdFKZkydQIx7ikmyGsC5rViRX83FVojaInUPt5OJ7DwQAy8TRfLTaKzHtAG
# Wt32k89XdZn1+oYaZ3izv5b+NNy951JW5bPldXvXQZEF3F1p45UNQ7n8g5Y5lXts
# gFpPE3LG130pekS6UqQq1UFGCSD+IqC2WzCNvIkM1ddw+IdS/drvrFEuB7NO/tAJ
# 2nDvmPpW5m3btVdL3OUsJRXIni54TvjanJ6GLMpX8xrlyJKLGoKWesO8UBJp2A5a
# Ros66yb6I8m2sIG+QgCk+Nb+MC7H0kb25Y51/fLMudCHW8wGEGC7gzW3XmfeR+yZ
# SPGkoRX+rYxijjlVTzkWubFjnf+3AgMBAAGjggE+MIIBOjAPBgNVHRMBAf8EBTAD
# AQH/MB0GA1UdDgQWBBS2oVQ5AsOgP46KvPrU+Bym0ToO/TAfBgNVHSMEGDAWgBQI
# ds3LB/8k9sXN7buQvOKEN0Z19zAOBgNVHQ8BAf8EBAMCAQYwLwYDVR0fBCgwJjAk
# oCKgIIYeaHR0cDovL2NybC5jZXJ0dW0ucGwvY3RuY2EuY3JsMGsGCCsGAQUFBwEB
# BF8wXTAoBggrBgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTAx
# BggrBgEFBQcwAoYlaHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBsL2N0bmNhLmNl
# cjA5BgNVHSAEMjAwMC4GBFUdIAAwJjAkBggrBgEFBQcCARYYaHR0cDovL3d3dy5j
# ZXJ0dW0ucGwvQ1BTMA0GCSqGSIb3DQEBDAUAA4IBAQBRwqFYFiIQi/yGMdTCMtNc
# +EuiL2o+TfirCB7t1ej65wgN7LfGHg6ydQV6sQv613RqAAYfpM6q8mt92BHAEQjU
# Dk1hxTqo+rHh45jq4mP9QfWTfQ28XZI7kZplutBfTL5MjWgDEBbV8dAEioUz+Tfn
# Wy4maUI8us281HrpTZ3a50P7Y1KAhQTEJZVV8H6nnwHFWyj44M6GcKYnOzn7OC6Y
# U2UidS3X9t0iIpGW691o7T+jGZfTOyWI7DYSPal+zgKNBZqSpyduRbKcYoY3DaQz
# jteoTtBKF0NMxfGnbNIeWGwUUX6KVKH27595el2BmhaQD+G78UoA+fndvu2q7M4K
# MIIF9TCCA92gAwIBAgIQHaJIMG+bJhjQguCWfTPTajANBgkqhkiG9w0BAQwFADCB
# iDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0pl
# cnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNV
# BAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTgx
# MTAyMDAwMDAwWhcNMzAxMjMxMjM1OTU5WjB8MQswCQYDVQQGEwJHQjEbMBkGA1UE
# CBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxJDAiBgNVBAMTG1NlY3RpZ28gUlNBIENvZGUgU2ln
# bmluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAIYijTKFehif
# SfCWL2MIHi3cfJ8Uz+MmtiVmKUCGVEZ0MWLFEO2yhyemmcuVMMBW9aR1xqkOUGKl
# UZEQauBLYq798PgYrKf/7i4zIPoMGYmobHutAMNhodxpZW0fbieW15dRhqb0J+V8
# aouVHltg1X7XFpKcAC9o95ftanK+ODtj3o+/bkxBXRIgCFnoOc2P0tbPBrRXBbZO
# oT5Xax+YvMRi1hsLjcdmG0qfnYHEckC14l/vC0X/o84Xpi1VsLewvFRqnbyNVlPG
# 8Lp5UEks9wO5/i9lNfIi6iwHr0bZ+UYc3Ix8cSjz/qfGFN1VkW6KEQ3fBiSVfQ+n
# oXw62oY1YdMCAwEAAaOCAWQwggFgMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvA
# nfKyA2bLMB0GA1UdDgQWBBQO4TqoUzox1Yq+wbutZxoDha00DjAOBgNVHQ8BAf8E
# BAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHSUEFjAUBggrBgEFBQcDAwYI
# KwYBBQUHAwgwEQYDVR0gBAowCDAGBgRVHSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0
# dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9u
# QXV0aG9yaXR5LmNybDB2BggrBgEFBQcBAQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6
# Ly9jcnQudXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FBZGRUcnVzdENBLmNydDAl
# BggrBgEFBQcwAYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0B
# AQwFAAOCAgEATWNQ7Uc0SmGk295qKoyb8QAAHh1iezrXMsL2s+Bjs/thAIiaG20Q
# BwRPvrjqiXgi6w9G7PNGXkBGiRL0C3danCpBOvzW9Ovn9xWVM8Ohgyi33i/klPeF
# M4MtSkBIv5rCT0qxjyT0s4E307dksKYjalloUkJf/wTr4XRleQj1qZPea3FAmZa6
# ePG5yOLDCBaxq2NayBWAbXReSnV+pbjDbLXP30p5h1zHQE1jNfYw08+1Cg4LBH+g
# S667o6XQhACTPlNdNKUANWlsvp8gJRANGftQkGG+OY96jk32nw4e/gdREmaDJhlI
# lc5KycF/8zoFm/lv34h/wCOe0h5DekUxwZxNqfBZslkZ6GqNKQQCd3xLS81wvjqy
# VVp4Pry7bwMQJXcVNIr5NsxDkuS6T/FikyglVyn7URnHoSVAaoRXxrKdsbwcCtp8
# Z359LukoTBh+xHsxQXGaSynsCz1XUNLK3f2eBVHlRHjdAd6xdZgNVCT98E7j4viD
# vXK6yz067vBeF5Jobchh+abxKgoLpbn0nu6YMgWFnuv5gynTxix9vTp3Los3QqBq
# gu07SqqUEKThDfgXxbZaeTMYkuO1dfih6Y4KJR7kHvGfWocj/5+kUZ77OYARzdu1
# xKeogG/lU9Tg46LC0lsa+jImLWpXcBw8pFguo/NbSwfcMlnzh6cabVgwggaVMIIE
# faADAgECAhEA8WQljAm24nviDjJgjkv0qDANBgkqhkiG9w0BAQwFADBWMQswCQYD
# VQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYD
# VQQDExtDZXJ0dW0gVGltZXN0YW1waW5nIDIwMjEgQ0EwHhcNMjEwNTE5MDU0MjQ2
# WhcNMzIwNTE4MDU0MjQ2WjBQMQswCQYDVQQGEwJQTDEhMB8GA1UECgwYQXNzZWNv
# IERhdGEgU3lzdGVtcyBTLkEuMR4wHAYDVQQDDBVDZXJ0dW0gVGltZXN0YW1wIDIw
# MjEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDVYb6AAL3dhGPuEmWY
# HXhUi0b6xpEWGro9Hny+NBj26L94gmI8kONVYdu2Cz9Bftkiyvk4+3MFDrkovZZQ
# 8WDcmGXltX4xAwPAcjXEbXgEZ0exEP5Ae2bkwKlTiyUXCaq0D9JEaK5t4Kq7rH7r
# ndKd5kX7KARcMFWEN+ikV1cgGlKgqmJSTk0Bvbgbc67oolIhtohcEktZZFut5VJx
# TJ1OKsRR3FUmN+4QrAk0RIv4dw2Z4sWilqbdBaBS/5hqLt58sptiORkxnijr33Vn
# viLP2+wbWyQM5k/AgrKj8lk6A5C8V/dShj6l/TqqRMykGAKOmi6CcvGbUDibPKkj
# lxlALd4mHLFujWoE91GicKUKfVkLsFqplb/dPPXQjw2TCmZbAegDQlsAppndi9UU
# ZxHvPcryyy0Eyh1y4Gn7Xv1vEwnwBisZjB72My8kzUQ0gjxP26vhBkvF2Cic16nV
# AHxyGOPm0Y0v7lFmcSyYVWg1J56YZb+QAJZCL7BJ9CBSJpAXNGxcNURN0baABlZT
# Hn3bbBPOBhOSY9vbGwL34nOmTFpRG5mP6HQVXc/EO9cj856a9aueDGyz2hclMIZi
# jGEa5rwacGtPw1HzWpgNAOI24ChDBRQ8YmD23IN1rmLlzCMsRZ9wFYIvNDtMJVMS
# QgC0+XQBFPOe69kPwxgPNN4CCwIDAQABo4IBYjCCAV4wDAYDVR0TAQH/BAIwADAd
# BgNVHQ4EFgQUxUcSTnJXtkQUa4hxGhSsMbk/uggwHwYDVR0jBBgwFoAUvlQCL79A
# bHNDzqwJJU6eQ0Qa7uAwDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsG
# AQUFBwMIMDMGA1UdHwQsMCowKKAmoCSGImh0dHA6Ly9jcmwuY2VydHVtLnBsL2N0
# c2NhMjAyMS5jcmwwbwYIKwYBBQUHAQEEYzBhMCgGCCsGAQUFBzABhhxodHRwOi8v
# c3ViY2Eub2NzcC1jZXJ0dW0uY29tMDUGCCsGAQUFBzAChilodHRwOi8vcmVwb3Np
# dG9yeS5jZXJ0dW0ucGwvY3RzY2EyMDIxLmNlcjBABgNVHSAEOTA3MDUGCyqEaAGG
# 9ncCBQELMCYwJAYIKwYBBQUHAgEWGGh0dHA6Ly93d3cuY2VydHVtLnBsL0NQUzAN
# BgkqhkiG9w0BAQwFAAOCAgEAN3PMMLfCX4nmqnSsHU2rZhE/dkqrdSYLvI3U9i49
# hxs+i+9oo5mJl4urPLZJ0xIz6B7CHFBNW9dFwgahnFMXiT7QnPuZ5CAwfL/9CfsA
# L3XdnS0AWll+7ISomRo8d51bfpHHt3P3jx9C6Imh1A73JSp90Cq0NqPqnEflrVxY
# X+sYa2SO9vGsRMYshU7uzE1V5cYWWoFUMaDHpwQuH4DNXiZO6D7f8QGWnXNHXu6S
# 3SlaYDG4Yox7SIW1tQv0jskmF1vdNfoxVAymQGRdNLsGzAXn6OPAUiw1xQ6M1qpj
# K4UnKTUiFJfvgDXbT1cvrYsJrybB/41so+DsAt0yjKxbpS5iP7SpxyHsnch0VcI5
# 4sIf0K66f4LJGocBpDTKbU1AOq3OvHbVqI7Vwqs+TGCu7TKqrTL2NQTRDAxHkso7
# FtH841R2A2lvYSFDfGx87B1NvPWYU3mY/GRsmQx+RgA8Pl/7Nvp7ZAY+AU8mDVr2
# KXrFP4unpswVBQlHxtIOxz6jeyfdLIG2oFJll3ipcASHav/obYEt/F1GRlJ+mFIQ
# tKDadxUBmfhRlgIgYvEEtuJGERHuxfMD26jLmixu8STPGRRco+R5Bdgu+qFbnymK
# fuXO4sR96JYqaOOxilcN/xr7ms13iS7wqANpd2txKZjPy3wdWniVQcuL7yCXD2uE
# c20wgga5MIIEoaADAgECAhEA5/9pxzs1zkuRJth0fGilhzANBgkqhkiG9w0BAQwF
# ADCBgDELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVz
# IFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEk
# MCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMB4XDTIxMDUxOTA1
# MzIwN1oXDTM2MDUxODA1MzIwN1owVjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFz
# c2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFt
# cGluZyAyMDIxIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA6RIf
# BDXtuV16xaaVQb6KZX9Od9FtJXXTZo7b+GEof3+3g0ChWiKnO7R4+6MfrvLyLCWZ
# a6GpFHjEt4t0/GiUQvnkLOBRdBqr5DOvlmTvJJs2X8ZmWgWJjC7PBZLYBWAs8sJl
# 3kNXxBMX5XntjqWx1ZOuuXl0R4x+zGGSMzZ45dpvB8vLpQfZkfMC/1tL9KYyjU+h
# tLH68dZJPtzhqLBVG+8ljZ1ZFilOKksS79epCeqFSeAUm2eMTGpOiS3gfLM6yvb8
# Bg6bxg5yglDGC9zbr4sB9ceIGRtCQF1N8dqTgM/dSViiUgJkcv5dLNJeWxGCqJYP
# gzKlYZTgDXfGIeZpEFmjBLwURP5ABsyKoFocMzdjrCiFbTvJn+bD1kq78qZUgAQG
# Gtd6zGJ88H4NPJ5Y2R4IargiWAmv8RyvWnHr/VA+2PrrK9eXe5q7M88YRdSTq9TK
# bqdnITUgZcjjm4ZUjteq8K331a4P0s2in0p3UubMEYa/G5w6jSWPUzchGLwWKYBf
# eSu6dIOC4LkeAPvmdZxSB1lWOb9HzVWZoM8Q/blaP4LWt6JxjkI9yQsYGMdCqwl7
# uMnPUIlcExS1mzXRxUowQref/EPaS7kYVaHHQrp4XB7nTEtQhkP0Z9Puz/n8zIFn
# USnxDof4Yy650PAXSYmK2TcbyDoTNmmt8xAxzcMCAwEAAaOCAVUwggFRMA8GA1Ud
# EwEB/wQFMAMBAf8wHQYDVR0OBBYEFL5UAi+/QGxzQ86sCSVOnkNEGu7gMB8GA1Ud
# IwQYMBaAFLahVDkCw6A/joq8+tT4HKbROg79MA4GA1UdDwEB/wQEAwIBBjATBgNV
# HSUEDDAKBggrBgEFBQcDCDAwBgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vY3JsLmNl
# cnR1bS5wbC9jdG5jYTIuY3JsMGwGCCsGAQUFBwEBBGAwXjAoBggrBgEFBQcwAYYc
# aHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTAyBggrBgEFBQcwAoYmaHR0cDov
# L3JlcG9zaXRvcnkuY2VydHVtLnBsL2N0bmNhMi5jZXIwOQYDVR0gBDIwMDAuBgRV
# HSAAMCYwJAYIKwYBBQUHAgEWGGh0dHA6Ly93d3cuY2VydHVtLnBsL0NQUzANBgkq
# hkiG9w0BAQwFAAOCAgEAuJNZd8lMFf2UBwigp3qgLPBBk58BFCS3Q6aJDf3TISoy
# tK0eal/JyCB88aUEd0wMNiEcNVMbK9j5Yht2whaknUE1G32k6uld7wcxHmw67vUB
# Y6pSp8QhdodY4SzRRaZWzyYlviUpyU4dXyhKhHSncYJfa1U75cXxCe3sTp9uTBm3
# f8Bj8LkpjMUSVTtMJ6oEu5JqCYzRfc6nnoRUgwz/GVZFoOBGdrSEtDN7mZgcka/t
# S5MI47fALVvN5lZ2U8k7Dm/hTX8CWOw0uBZloZEW4HB0Xra3qE4qzzq/6M8gyoU/
# DE0k3+i7bYOrOk/7tPJg1sOhytOGUQ30PbG++0FfJioDuOFhj99b151SqFlSaRQY
# z74y/P2XJP+cF19oqozmi0rRTkfyEJIvhIZ+M5XIFZttmVQgTxfpfJwMFFEoQrSr
# klOxpmSygppsUDJEoliC05vBLVQ+gMZyYaKvBJ4YxBMlKH5ZHkRdloRYlUDplk8G
# Ua+OCMVhpDSQurU6K1ua5dmZftnvSSz2H96UrQDzA6DyiI1V3ejVtvn2azVAXg6N
# njmuRZ+wa7Pxy0H3+V4K4rOTHlG3VYA6xfLsTunCz72T6Ot4+tkrDYOeaU1pPX1C
# BfYj6EW2+ELq46GP8KCNUQDirWLU4nOmgCat7vN0SD6RlwUiSsMeCiQDmZwgwrUx
# ggY6MIIGNgIBATCBkDB8MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBN
# YW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExp
# bWl0ZWQxJDAiBgNVBAMTG1NlY3RpZ28gUlNBIENvZGUgU2lnbmluZyBDQQIQDapM
# mE8NUKJDb44cpXT3cDAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAA
# oQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4w
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUi3t/PszRPRv9188iIassG1rj
# zakwDQYJKoZIhvcNAQEBBQAEggEASawuBgpy25cDd10eGYCCfWBa71cx8IJTMNAF
# 9OzSDzXZ68eBhDCdqXyU/jVzCl+8gxoPwIVfNEsCbAu8ftJBcL2Dj8na40xiyiSu
# EF1RrTlWYme6wqswAfqeJDIdu0sw7Uv0Bf3qXNAIBwt7OGpYboUGe51Cfa/n47M+
# xyopF3EiSSr6hY2vtQ1gHq2TPiKtFBhtxxfjTHJf9dh26ioS8GzOQmqXOZ61m7V8
# EFi79vNEaMkHLYoXsosw7b79jL90aBDbC+KJl/JEK0TFdJGwll/qaJ6q/cJwDhce
# B71mtSFfP7gT2dbbzbnfHUWYLFSGS3OHfhqsDYkYmFdxyGucXKGCBAQwggQABgkq
# hkiG9w0BCQYxggPxMIID7QIBATBrMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3Rh
# bXBpbmcgMjAyMSBDQQIRAPFkJYwJtuJ74g4yYI5L9KgwDQYJYIZIAWUDBAICBQCg
# ggFXMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcN
# MjEwOTI3MTYwNDQ2WjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCAbWb/o5XcrrPZD
# u3mstI6BWHhPIcVUrhNHbToaPgXF0zA/BgkqhkiG9w0BCQQxMgQw44NTJsVEMyC+
# WPQmq5jfjzpA8tCoX87RdLodqwAAvJffTSU5nKwPc8XG+cbmbnDIMIGgBgsqhkiG
# 9w0BCRACDDGBkDCBjTCBijCBhwQU0xHGlTEbjOc/1bVTGKzfWYrhmxMwbzBapFgw
# VjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhEA8WQljAm2
# 4nviDjJgjkv0qDANBgkqhkiG9w0BAQEFAASCAgDDe2FtbiklZdHIZfyqH6Y4Ghch
# 806eIJ3ciazUR8/w7CrjEbwr2oa7NNLga22/hjVqcqYFQkSpzieYrRaYUzSQ1Qk3
# 2J6NKb5K35sNg8krAwLbVLOFIUm2XeIErsTL83egOK+rZEPvfSFX470ZModxoOGe
# wVWQXp9bn0CIqkHe7G9BDs22eWp73lokvlqwyA+vIGzexQv0BBG6mp5SYVB9BuLT
# CLldTHuhwObg/uCxyG/QmIazQH1eFT/eV7gMiv1hu7+pjkOa23AKlRz1V5CbLSFv
# 7hFm9FrK/0f0oCI9zEomH62503i93NajpfDD8XH9xC5I60HOZ8X2qpgDzlrMTcxg
# 73WRMqbU4UJ1D7r00OPmHWAapX1F8LbBejBGIJtmxj7iT1t64GNw5yQBETE1xQ5C
# C55QICWHHD7+uZmK/lHZrW+Mo1p7wtakKzcIiPeGkqHNn905IbwKM0fqR3jdFXW1
# 8YMuEk5W0KbXdC+VE1zRac3nFtnLMv3EwkhV6k4kJi3c8pzwtGpsfwl9xowKHlPK
# iHBHN4DoaywVe2e1fmMeieTLgazLaZ8PKRu18pPa+H2iTNNmYiIzn4XU9FmL17Yj
# //v/XznmHbmKqCLK6Llg6Qqrjh9OOIiO6njSsLaHjGXBVgcQjVmSt68jyJt3znLf
# dxbsVtIdsP4/O59H4A==
# SIG # End signature block
