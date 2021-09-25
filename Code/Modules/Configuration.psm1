﻿function Get-PolicyApplicatorConfiguration {
   <#  
    .Synopsis  
        Builds a config object from the registry.
          
    .Description  
        Gets the PolicyApplicator configuration from the registry and parses it into an object that later can be used to write into the specific files.
          
    .Notes  
        Author        : Hauke Goetze
      
        Version        : 1.0 - 2021/03/22 - Started with this version table.        
     
          
    .Inputs  
        System.String  
          
    .Outputs  
        System.Array
          
    .Parameter RegistryPath  
        Specifies the path of the registry where the function should search for PolicyApplicator PolicySets.
          
    .Example  
        $configs = Get-PolicyApplicatorConfiguration "HKLM:\Software\Policies\PolicyApplicator" 
        -----------  
        Description  
        Searches in the registry key for PolicySets and stores them in the configs array.
    #>  
param(
        [ValidateNotNullOrEmpty()]  
        [ValidateScript({Test-Path $_})]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$RegistryPath
)
$config = @();

$registryKeys = Get-ChildItem -Recurse -Path $RegistryPath | WHERE { $_.PSChildName.StartsWith("PolicySet:") }
forEach ( $registryKey in $registryKeys ) {
    if ( $registryKey.PSChildName.StartsWith("PolicySet:") ) {

        $FileType = $registryKey.GetValue("Mode")
        if ( $registryKey.GetValue("operation") ) {
            $fileOperation = $registryKey.GetValue("operation");
        } else {
            if ( $registryKey.GetValue("CreateFile") ) {
                $fileOperation = "create";
            } else {
                $fileOperation = "update";
            }
        }

        $FilePath = $registryKey.GetValue("Path");
        $Encoding = $registryKey.GetValue("Encoding");

        #### Resolve system variables tagged with %-symbol
        Select-String -Pattern '\%(.+?)\%' -InputObject $FilePath -AllMatches |
            ForEach-Object {$_.Matches} |
                ForEach-Object  {
                $variable = $_.Groups[1].Value

                $resolvedVariabel = [System.Environment]::GetEnvironmentVariable($variable)
                $resolvedVariabel
                $FilePath = $filepath -replace "%$variable%", $resolvedVariabel
            } 


        $rules = @();

        $registryKeyNames = $registryKey.GetSubKeyNames() | sort { [int]($_ -replace '\D')}

        ForEach ( $registryKeyName in $registryKeyNames ) {
            $configKey = $registryKey.OpenSubKey($registryKeyName)

            switch ( $FileType ) {
                "ini" {
                    $iniSection = $configKey.GetValue("section");
                    $iniKey = $configKey.GetValue("key");
                    $iniValue = $configKey.GetValue("value");
                    $iniOperation = $configKey.GetValue("operation");
                    
                    $rule = @{
                        "Section" = $iniSection;
                        "Key" = $iniKey;
                        "Value" = $iniValue;
                        "Operation" = $iniOperation;
                    }

                    $rules += $rule;
                }
                "list" {
                    
                    
                    $operation = $configKey.GetValue("operation");

                    $list = @()
                    $listKey = $configKey.OpenSubKey("list")
                    if ( $listKey ) {
                        ForEach ( $listKeyName in $listKey.GetValueNames() ) {
                            $list += $listKey.GetValue($listKeyName)
                        }
                    }

                    $rule = @{
                        "operation" = $operation;
                        "list" = $list;
                    }

                    $rules += $rule;
                }
                "xml" {
                    $xpath = $configKey.GetValue("xpath");
                    $value = $configKey.GetValue("value");
                    $operation = $configKey.GetValue("operation");

                    $namespace = @{}
                    $namespaceKey = $configKey.OpenSubKey("namespace")
                    if ( $namespaceKey ) {
                        ForEach ( $namespaceKeyValue in $namespaceKey.GetValueNames() ) {
                            $namespace[$namespaceKeyValue] = $namespaceKey.GetValue($namespaceKeyValue);
                        }
                    }

                    $rule = @{
                        "xpath" = $xpath;
                        "value" = $value;
                        "Operation" = "$operation";
                        "Namespace" = $namespace;
                    }

                    $rules += $rule;
                }
                "json" {
                    
                    $jsonPath = $configKey.GetValue("JSONPath");
                    $value = $configKey.GetValue("value");
                    $operation = $configKey.GetValue("operation");
 

                    $rule = @{
                        "JSONPath" = $jsonPath;
                        "value" = $value;
                        "Operation" = "$operation"
                    }

                    $rules += $rule;
                }
            }
        }

        $fileConfig = @{ "FileType" = $FileType; "FilePath" = $FilePath; "Operation" = $fileOperation; "Encoding" = $Encoding; "Rules" = $rules }
        if ( $FileType -ne "Disabled" ) {
            $config += $fileConfig
        }
    }
}
    $config;
}

# Set-AuthenticodeSignature "$env:userprofile\GitHub\PolicyApplicator-for-Microsoft-Intune\Code\Modules\Configuration.psm1" @(Get-ChildItem cert:\CurrentUser\My -codesigning)[0] -TimestampServer http://time.certum.pl
# SIG # Begin signature block
# MIIk+QYJKoZIhvcNAQcCoIIk6jCCJOYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUaR51qQ30nXrZ0VWSfwYkxSL1
# jBeggh4pMIIFCTCCA/GgAwIBAgIQDapMmE8NUKJDb44cpXT3cDANBgkqhkiG9w0B
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
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU2FPqJy34HfDtchxRmD2h53ai
# 8PYwDQYJKoZIhvcNAQEBBQAEggEAdDxzYeAR5DlE469S0UfvnIguSCvVQTnLWFFm
# YDFO/A4WbNEYwJLa7hzCvHHXowJqZ1h4kpuLS1imq9u6OlDtPfU0RD7jkjp40C5m
# 6KoA1AE8kEd4BbeeOUHfASeQLX6Y8wjfTKJ2qBKFbdn5G7dfH9lX1ikgaLuvNLcq
# XuEO+wTTRLe3w947ZhUv7zB7XKbJTmqoPHuCQiglL0KHwnfoSrU6tB+AuRn5T3Of
# orCKrij7ESxPakMDIW5jZBRlFpt1NXU05V9OJlhN6IIUp9dYuufJvihjbtl9Pxu/
# 2M18E3B8wZylSgREls4HEF3pbksEb2kd/EFLwpwtp8CO4WwTOaGCBAQwggQABgkq
# hkiG9w0BCQYxggPxMIID7QIBATBrMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3Rh
# bXBpbmcgMjAyMSBDQQIRAPFkJYwJtuJ74g4yYI5L9KgwDQYJYIZIAWUDBAICBQCg
# ggFXMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcN
# MjEwOTI1MTkzMDAyWjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCAbWb/o5XcrrPZD
# u3mstI6BWHhPIcVUrhNHbToaPgXF0zA/BgkqhkiG9w0BCQQxMgQwa0k1lOMB9Ztz
# /VLQ42HpRj0K6IAtocimVQcfhkHw46yVLaahulB37NtV6HWW9pJGMIGgBgsqhkiG
# 9w0BCRACDDGBkDCBjTCBijCBhwQU0xHGlTEbjOc/1bVTGKzfWYrhmxMwbzBapFgw
# VjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhEA8WQljAm2
# 4nviDjJgjkv0qDANBgkqhkiG9w0BAQEFAASCAgBBYMvUz+Mp1eu4Xy1QFkQxAFvA
# r7AOasCpGeXrvNKG+36SFITWChvRLXUeKoNjllyU1q/sR+FDv5eIb4Y5mWcw2V8C
# yrcLCsQLj7p5F6151i4AmjrY7fSYQ/oEqnFdERKuB7bP1E5Zn/qShyrB6UmY4q/O
# 1aMrFYpFy2dWzloVvwhbzTEXtVdXqquu52IsoMPslwI8u4dndqbUXK3/zmGdJvS5
# mSSEkrXJrCmnaF7EZlg+z1/m+0tAp0AIPfhc+UYvAmEZYcjs/MaliTkqtdq0AdE7
# 1u37omzJbp5NW2et37xlnW7YLNM+ZJaN3AS6AcA2Mc8NfRMSO901xMmGuJPp/uig
# czRHhF7EFWa7LbRsm/lImz49a3oInH+cA5emn4XnWXTBLPymVexzy2JoeXav+8+N
# dh9qxXaoxckepI5H0IbAf+5XnC9rZX61qeKCNaBl5f2FuWsBSzFYn8U3zZ2Ym89/
# PZxgMBUEIUTubCUsLAv5/20ga6jbuGnQ5C1XG3No2aNapMOfzOh2erCHa/7GF4U6
# GD/ria0soEdhSh9sfOM4MNiteWdUpuv/k8qeY73TdSjCtS4bFRG1VXEOVdSID67g
# tgaU8H/BhiCZ2VCMCsEQcd1chFYTPnRv/Wdv0E9gqNkRHgX/c/Je4E9Rsdl/b0jg
# I0GT8HBFuiBPZnaLCQ==
# SIG # End signature block
