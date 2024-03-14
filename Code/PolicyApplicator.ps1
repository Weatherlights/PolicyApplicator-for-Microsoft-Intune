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
# SIG # Begin signature block
# MIIlHAYJKoZIhvcNAQcCoIIlDTCCJQkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBTf7AJnRKAi5Zp
# 3h02F6ghhFupKAuF/6pnPBCd4urPgqCCHikwggUJMIID8aADAgECAhANqkyYTw1Q
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
# AQkEMSIEIMAtlqnTHesrEpdypsesxkA58DkerWbf0dMGA1Hm0lCeMA0GCSqGSIb3
# DQEBAQUABIIBAIw+3bAIkaN6YQeMEivi/sCyr1jibPKzKvkGOPmwmqu/CWf8XsgB
# IvhWil2XE9nclirJtYBUUIAhfgLPqmYzmqFarl6MJMcAp6sJkLSw2ZstGqMLi+Vu
# NNbLIsRhdGqkguivvT5PPt9rjTDWeQAXeWhyLvrKCkFG6Xe5bfRY1GS/EXNFT3JX
# UY467P+cqwxRXZLkIqIb/06RvZQ122yjA7LxoXiOaXrhAJIgEoMA0TBdN85vzCju
# 94Vk7CC8xuAI+8X+5pdyHoxg7E2SLRESji+UO3jsfyZwictcC1GRjuqa02FOSOcz
# ZJYn6AE7gyv4AY+bhHIzN+nh5NdKWe8Hu56hggQCMIID/gYJKoZIhvcNAQkGMYID
# 7zCCA+sCAQEwajBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEg
# U3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0YW1waW5nIDIwMjEg
# Q0ECEAnFzPi7Zn1xN6rBWYAGyzEwDQYJYIZIAWUDBAICBQCgggFWMBoGCSqGSIb3
# DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjQwMzA3MjI1NTQ3
# WjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDqlUux0EC0MUBI2GWfj2FdiHQszOBn
# kuBWAk1LADrTHDA/BgkqhkiG9w0BCQQxMgQwn1TfpRGGyKROgVsaTrv+fkhaYBk/
# tEkoQPDxM95L6ycCl+RKS5xqaJnkiP7Q+fN1MIGfBgsqhkiG9w0BCRACDDGBjzCB
# jDCBiTCBhgQUD0+4VR7/2Pbef2cmtDwT0Gql53cwbjBapFgwVjELMAkGA1UEBhMC
# UEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMb
# Q2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhAJxcz4u2Z9cTeqwVmABssxMA0G
# CSqGSIb3DQEBAQUABIICAH9blZDZNmzYkGRLsqpSHnAro5y6SlPdOzuSw2qAY9SX
# ztzNJHWbq+qNM3bS7N02+zA8cBbAaP4iHQSUZjeZ3sx0GAjufV/p8aQYAVHvO4I9
# NqQU8MWMGo031yD1q16UAagUqDKjIYOLJy0YnllShqj5GiB6B12CLHZHqwgRjRlI
# Mesz5MqD0kboRJMPyB2MPPUU2L20R7PUL5GpqcJ3k+XqkYTLPkTLlFizIEktUx/C
# QiD5RT2B9IO15k87jNBMay7mu+gSs3VJqLKxQPmIwNiCfoNBO/Xopo1jXqOGjt5H
# +HwUpp+FyplsThI3iWudhirK4KS9/AXmMJ7fNRqNwru4JEug8jJj+x6Rgsqz4XyP
# HqFem4CYf1Ym8p2/SxqKe4VG53vcPUI7hbu/hZS93mzPuE1Ye93LHLjNkkAGXeHq
# siliipl3ob45394War46LaMXDfGjTChbXtKOXYNQoFm+Z8QqSgUJqDyklu01Gjeg
# SBPYYjAXxq13svt7jurqQXEAhR+TSlUhtX9C94ey8KA9Gmk7xUAUeBmtDv0okEfT
# +mV3DPuWnFHBLGoOkbx6w1uzee50Pq32DrojdIC5U8vYWHY5qF34x8HG6OeoOWaB
# krEX4waR7bJJz+xOZ4kAedw4ZM/YZ33wNM+Jq6mvE/qEShsl/zHeWfK9c2YyOTMC
# SIG # End signature block
