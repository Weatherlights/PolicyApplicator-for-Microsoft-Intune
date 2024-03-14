Function Get-IniContent {  
    <#  
    .Synopsis  
        Gets the content of an INI file  
          
    .Description  
        Gets the content of an INI file and returns it as a hashtable  
          
    .Notes  
        Author        : Oliver Lipkau <oliver@lipkau.net>  
        Blog        : http://oliver.lipkau.net/blog/  
        Source        : https://github.com/lipkau/PsIni 
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91 
        Version        : 1.0 - 2010/03/12 - Initial release  
                      1.1 - 2014/12/11 - Typo (Thx SLDR) 
                                         Typo (Thx Dave Stiff) 
                         1.3 - 2021/03/27 - By Hauke Goetze: Modified to ignore comments and to better mark no section areas. 
          
        #Requires -Version 2.0  
          
    .Inputs  
        System.String  
          
    .Outputs  
        System.Collections.Hashtable  
          
    .Parameter FilePath  
        Specifies the path to the input file.  
          
    .Example  
        $FileContent = Get-IniContent "C:\myinifile.ini"  
        -----------  
        Description  
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent  
      
    .Example  
        $inifilepath | $FileContent = Get-IniContent  
        -----------  
        Description  
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent  
      
    .Example  
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini"  
        C:\PS>$FileContent["Section"]["Key"]  
        -----------  
        Description  
        Returns the key "Key" of the section "Section" from the C:\settings.ini file  
          
    .Link  
        Out-IniFile  
    #>  
      
    [CmdletBinding()]  
    Param(  
        [ValidateNotNullOrEmpty()]  
        [ValidateScript({Test-Path $_})]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$FilePath  
    )  
      
    Begin  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}  
          
    Process  
    {  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"  
              
        $ini = @{}  
        switch -regex -file $FilePath  
        {  
            "^\[(.+)\]" # Section  
            {  
                $section = $matches[1]  
                $ini[$section] = @{}  
                $CommentCount = 0  
            }   
            "^([^#;]{1}.+?)\s*=\s*(.*)" # Key  
            {  
                if (!($section))  
                {  
                    $section = "__No-Section__"  
                    $ini[$section] = @{}  
                }  
                $name,$value = $matches[1..2]  
                $ini[$section][$name] = $value  
            }  
        }  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"  
        Return $ini  
    }  
          
    End  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}  
} 

Function Out-IniFile {  
    <#  
    .Synopsis  
        Write hash content to INI file  
          
    .Description  
        Write hash content to INI file  
          
    .Notes  
        Author        : Oliver Lipkau <oliver@lipkau.net>  
        Blog        : http://oliver.lipkau.net/blog/  
        Source        : https://github.com/lipkau/PsIni 
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91 
        Version        : 1.0 - 2010/03/12 - Initial release  
                      1.1 - 2012/04/19 - Bugfix/Added example to help (Thx Ingmar Verheij)  
                      1.2 - 2014/12/11 - Improved handling for missing output file (Thx SLDR)
                      1.3 - 2021/03/27 - By Hauke Goetze: Better support for no section keys. 
          
        #Requires -Version 2.0  
          
    .Inputs  
        System.String  
        System.Collections.Hashtable  
          
    .Outputs  
        System.IO.FileSystemInfo  
          
    .Parameter Append  
        Adds the output to the end of an existing file, instead of replacing the file contents.  
          
    .Parameter InputObject  
        Specifies the Hashtable to be written to the file. Enter a variable that contains the objects or type a command or expression that gets the objects.  
  
    .Parameter FilePath  
        Specifies the path to the output file.  
       
     .Parameter Encoding  
        Specifies the type of character encoding used in the file. Valid values are "Unicode", "UTF7",  
         "UTF8", "UTF32", "ASCII", "BigEndianUnicode", "Default", and "OEM". "Unicode" is the default.  
          
        "Default" uses the encoding of the system's current ANSI code page.   
          
        "OEM" uses the current original equipment manufacturer code page identifier for the operating   
        system.  
       
     .Parameter Force  
        Allows the cmdlet to overwrite an existing read-only file. Even using the Force parameter, the cmdlet cannot override security restrictions.  
          
     .Parameter PassThru  
        Passes an object representing the location to the pipeline. By default, this cmdlet does not generate any output.  
                  
    .Example  
        Out-IniFile $IniVar "C:\myinifile.ini"  
        -----------  
        Description  
        Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini  
          
    .Example  
        $IniVar | Out-IniFile "C:\myinifile.ini" -Force  
        -----------  
        Description  
        Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini and overwrites the file if it is already present  
          
    .Example  
        $file = Out-IniFile $IniVar "C:\myinifile.ini" -PassThru  
        -----------  
        Description  
        Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini and saves the file into $file  
  
    .Link  
        Get-IniContent  
    #>  
      
    [CmdletBinding()]  
    Param(  
        [switch]$Append,  
          
        [ValidateSet("Unicode","UTF7","UTF8","UTF32","ASCII","BigEndianUnicode","Default","OEM")]  
        [Parameter()]  
        [string]$Encoding = "Unicode",  
 
          
        [ValidateNotNullOrEmpty()]  
        [Parameter(Mandatory=$True)]  
        [string]$FilePath,  
          
        [switch]$Force,  
          
        [ValidateNotNullOrEmpty()]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [Hashtable]$InputObject,  
          
        [switch]$Passthru  
    )  
      
    Begin  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}  
          
    Process  
    {  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing to file: $Filepath"  
        if ( !(Test-Path -Path "$Filepath\..") ) {
                New-Item -Path $Filepath\.. -ItemType Directory
        }

        $NoSectionContent = "";
        $SectionContent = "";
          
        if ($append) {$outfile = Get-Item $FilePath}  
        else {$outFile = New-Item -ItemType file -Path $Filepath -Force:$Force}  
        if (!($outFile)) {Throw "Could not create File"}  
        foreach ($i in $InputObject.keys)  
        {  
            if (!($($InputObject[$i].GetType().Name) -eq "Hashtable"))  
            {  
                #No Sections  
                Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing key: $i"   
                $NoSectionContent += "$i=$($InputObject[$i])`n"
            } else {  
                #Sections  
                Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing Section: [$i]"  
                If ( $i -ne "__No-Section__" ) {
                    $SectionContent += "[$i]`n"
                }
                Foreach ($j in $($InputObject[$i].keys | Sort-Object))  
                {  
                    if ($j -match "^Comment[\d]+") {  
                        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing comment: $j"  
                        $SectionContent += "$($InputObject[$i][$j])`n" 
                    } else {  
                        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing key: $j" 
                        $SectionContent += "$j=$($InputObject[$i][$j])`n" 
                    }  
                      
                }  
                $SectionContent += "`n"
            }  
        }  
        Add-Content -Path $outFile -Value $NoSectionContent -Encoding $Encoding  
        Add-Content -Path $outFile -Value $SectionContent -Encoding $Encoding

        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Writing to file: $path"  
        if ($PassThru) {Return $outFile}  
    }  
          
    End  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}  
}


function Invoke-__NoSection__CleanUp{
    param(
        [ValidateNotNullOrEmpty()]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [Hashtable]$InputObject
    )

    if ( $InputObject["__No-Section__"] ) {
        ForEach ( $key in $InputObject["__No-Section__"].Keys ) {
            $InputObject[$key] = $InputObject["__No-Section__"][$Key];

        }

        $InputObject.Remove("__No-Section__");
    }

    return $InputObject;
}

function Invoke-IniRemediation {
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

    $new_config = $null;
    $compliance = "Compliant"
    $fileWasCreated = $false;

    If ( Test-Path -Path $FilePath ) {
        $current_config = Get-IniContent -FilePath $FilePath;
        $encoding = Get-FileEncoding -Path $FilePath;

        ForEach ( $rule in $rules ) {
            if ( $rule.Operation -ne "Delete" ) {
                $sectionExists = $false;

                if ( !($current_config[$rule["Section"]]) ) {
                    if ( ($rule.Operation -eq "Create") -or ($rule.Operation -eq "Replace") ) {
                        $current_config[$rule["Section"]] = @{};
                        $sectionExists = $true;
                    }
                } else {
                    $sectionExists = $true;
                }
                if ( $sectionExists -eq $true ) {
                    if ( $current_config[$rule["Section"]][$rule["Key"]] -ne $rule["Value"] ) {
                        $compliance = "Non-Compliant: Section: " + $rule["Section"] + " Key: " + $rule["Key"] + " is not '" + $rule["Value"] + "' but '"+ $current_config[$rule["Section"]][$rule["Key"]] + "'";

                        if ( (!$current_config[$rule["Section"]][$rule["Key"]]) -and ($rule.Operation -eq "Create") ) {
                            $current_config[$rule["Section"]][$rule["Key"]] = $rule["Value"];
                        }

                    
                        if ( ($rule.Operation -eq "Update") -or ($rule.Operation -eq "Replace") ) {
                            $current_config[$rule["Section"]][$rule["Key"]] = $rule["Value"];
                        }
                    }
                } else {
                    $compliance = "Non-Compliant: Section " + $rule["Section"] + " does not exist and is not beeing created.";
                }
            } else {
                if ( $current_config[$rule["Section"]] ) {
                    if ( $current_config[$rule["Section"]][$rule["Key"]] ) {
                        $current_config[$rule["Section"]].Remove($rule["Key"]);
                    }
                }
            }
        
        }

        $new_config = $current_config;
    }
    if ( !(Test-Path -Path $FilePath) -or ( ( $compliance -ne "Compliant" ) -and ( $Operation -eq "replace" ) ) ) {
        $compliance = "Non-Compliant: File needs to be (re-)created";
        if ( $action -eq "Remediate" ) {
###### Build new File #######
            $new_config = @{}
            ForEach ( $rule in $rules ) {
                if ( $rule.Operation -eq "Replace" -or $rule.Operation -eq "Create" ) {
                    if ( !($new_config[$rule["Section"]]) ) {
                        $new_config[$rule["Section"]] = @{};
                    }
                    $new_config[$rule["Section"]][$rule["Key"]] = $rule["Value"];
                }
            }
            $fileWasCreated = $true;  
        }
    }
    if ( $action -eq "Remediate" -and $compliance -ne "Compliant" ) {
        $new_config = Invoke-__NoSection__CleanUp -InputObject $new_config;
        if ( ( $fileWasCreate -eq $false ) -or ( $operation -eq "create") -or ( $Operation -eq "replace" ) ) {
            $new_config | Out-IniFile -FilePath $FilePath -Force -Encoding $Encoding;
        }
    }

    $compliance;
}
# SIG # Begin signature block
# MIIlHAYJKoZIhvcNAQcCoIIlDTCCJQkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAD3vG2iVYCk3LI
# ho/unyu078ZzgcgEwlMvJvfFgCUXMaCCHikwggUJMIID8aADAgECAhANqkyYTw1Q
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
# AQkEMSIEICMrYBmoBtEe03jOroCpz3ChY/FzCRuaIc3Jy+sksZtwMA0GCSqGSIb3
# DQEBAQUABIIBAMjXyZzUDSp+Li1UYQOHbDv7GFUQDriUClIyy07SNKxdV8iNRYqX
# MZUpaMDbKK5QecZ+mFEVxW1ltFRZ11niSsXXqGUUc+5wjvZ66096VorNE5WwZ3dO
# 0bJkR4qqYsxFYxTDXxoNUmnd3VuNARaoSyS7TY+4Kub3Bb+1yMphfxzZEVJOC/hS
# P1sdTKMcMDji+T5a9zj37VQRbNwiOAb0Z9HwjWLq5dsk5wclsR1mVY9tGPwzqTTg
# lxpcvO2cOVIAkdJupnSw/tv8t/h8JjSjBqkBdektdkcgtAsFq5wptENV5Z2JRJwv
# dyXOT62iTP/Cxdb2fpvR+J+caqN3X5POf1yhggQCMIID/gYJKoZIhvcNAQkGMYID
# 7zCCA+sCAQEwajBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEg
# U3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0YW1waW5nIDIwMjEg
# Q0ECEAnFzPi7Zn1xN6rBWYAGyzEwDQYJYIZIAWUDBAICBQCgggFWMBoGCSqGSIb3
# DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjQwMzA3MjI1NDI4
# WjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDqlUux0EC0MUBI2GWfj2FdiHQszOBn
# kuBWAk1LADrTHDA/BgkqhkiG9w0BCQQxMgQwYGDoc9BVGtXKgMo6KLfZz4d/N5/L
# rqmND5AaRYa3jChq69eXKRQO3aTi+eryJYDXMIGfBgsqhkiG9w0BCRACDDGBjzCB
# jDCBiTCBhgQUD0+4VR7/2Pbef2cmtDwT0Gql53cwbjBapFgwVjELMAkGA1UEBhMC
# UEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMb
# Q2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhAJxcz4u2Z9cTeqwVmABssxMA0G
# CSqGSIb3DQEBAQUABIICADm2Vx8VZ031ifcs1Rl+8f5ku5Z7tE8mHDBqGHpZPQyv
# sDckuOKgVa3Rm17tf2AzQTK0Fck+XErfyJt3Ix+SojCTgQQqXf8VXyCbxdvoFGHD
# OrbUfZudnpswpgstX9+fIKDd9c2V9J/F/risaILfJphHXlDbKxahxje22Ldivpou
# KHXZALRthuue8ep0Egrr6uC+SEWx9bG6cyf25SXYiihQfxK3w6wHgSrZMN/eiW0L
# J63cnL5QDshpTw/aJiTb+t7i6KtiIlxuk6QsVCxHOxO+zrLNcNxatUuflJ71MBc8
# pEek05isqjVlwLJxrMHBLncaVDVOeUhL9TQpH35sKtiN3CBQU3mS259154tJgPe7
# vfF6j1XgGLt9cdmWUrspxmaPluDc7BJ2HIrzQPtayfKv5FSzru8SVhVWwl8/1eaU
# X5cdMvI1TtAz8reelfE5E+1oq+TACZQaEsgTGgUXZ1OK3YeAwIhVFqb2kMjDQk03
# gREdz5haRwPExvoh5L5enImMtTk2OzauRU+hRF8adWvgN+5UblVStom9txYWjLVH
# uP0fDkAkQCnWmTaq1jYOjVD+yWy+YwYXPsaszfvIflkRBmGTEtgVSLjsJS8R/5q9
# PQUkl6Cv4J2zCHinMEX8VpP2Mft+7TolBdJovYLhtFuA8XCeBUACMMcGr7T8hSU1
# SIG # End signature block
