##### XPATH Remediation Script #####
# Author: Hauke Götze

function Test-XPathValueOnContent {
<#
.SYNOPSIS
    Tests for an xml node value.
.DESCRIPTION
    This function tests an xml node for a value. The xml node can be selected by providing an xpath query.
.PARAMETER Xml
    The xml document that you want to evaluate
.PARAMETER XPath
    The XPath to the node of the Xml document that you want to evaluate.
.PARAMETER Namespace
    A table of namespaces that are used in the provided xpath query.
.PARAMETER Value
    The value that you want to test against.
.PARAMETER Remediate
    If provided the function will replace the node value with the given value if they do not match.
.OUTPUTS
    bool
.NOTES
    Created by Hauke Goetze
.LINK
    https://policyapplicator.weatherlights.com
#>
    param(
        [Parameter(Mandatory=$True)][xml]$Xml,
        [Parameter(Mandatory=$True)][string]$XPath,
        [string]$Value,
        [switch]$Remediate,
        [System.Collections.Hashtable]$Namespace
    )

    $Element = Select-Xml -Xml $Xml -XPath $XPath -Namespace $Namespace;
    if ( $Element ) {
        if ( $Element.Node.InnerText -eq $Value -or $Element.Node.'#text' -eq $Value ) {
            return $true;
        } else {
            if ( $Remediate ) {
                $Element.Node.InnerText = $Value;
                return $true;
            } else {
                return $false;
            }
        }
    }

    return $false;
}

function Set-XmlNodeByXpath {
<#
.SYNOPSIS
    Creates or sets an xml node by a given xpath.
.DESCRIPTION
    This function can set or create an xml node by a given xpath query.
.PARAMETER Xml
    The xml document that you want to modify.
.PARAMETER XPath
    The XPath to the node of the Xml document that you want to modify or create. Warning: This function only works on simple xpath queries that provide a full path to the node and do not use functions but only implicit child selectors.
.PARAMETER Namespace
    A table of namespaces that are used in the provided xpath query.
.PARAMETER Value
    The value that you want to set.
.PARAMETER Operation
    Specifies what you want to do with the selected node (Create, delete, update or replace).
.NOTES
    Created by Hauke Goetze
.LINK
    https://policyapplicator.weatherlights.com
#>
    param(
        [Parameter(Mandatory=$True)][string]$Xpath, 
        [string]$Value,
        [ValidateSet("Create","Update", "Replace", "Delete")]  
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()][string]$Operation,  

        [Parameter(Mandatory=$True)][xml]$Xml,
        [System.Collections.Hashtable]$Namespace
    )

    $nodes = $Xpath -split "/";
    $currentPath = "";
    $selectedNode = "";
    $isAttributeSet = $false;

    $sthNeededToBeCreated = $false;

    if ( $Operation -eq "Create" -or $Operation -eq "Replace" ) {
        Foreach ( $node in $nodes ) {


        # Create the first element in case the xml document is empty.
            if ( $node -ne "" ) {
                # Here we check wether there is a namespace available for the current node.
                $nodeNamespaceURI = "";
                if ( $node -match ":" ) {
                   
                    ($nodeNamespacePrefix, $nodeTag) = $node -split ":";
                    $nodeNamespacePrefix = $nodeNamespacePrefix -replace "^@", "";
                    $nodeNamespaceURI = $Namespace[$nodeNamespacePrefix];
                   
                    if ( $nodeNamespacePrefix -eq "__Default__" ) {
                        $nodeNamespacePrefix = "";
                    }
                }
                else {
                    $nodeTag = $node;
                }


            $selectedNode = $node;
            if ($currentPath -eq "" ) {
                if ( !$xml.$nodeTag )  {
                    $xml.AppendChild($xml.CreateElement($nodeNamespacePrefix, $nodeTag, $nodeNamespaceURI)) # Create the first element.       
                }
            
            } else {
                $currentNode = Select-Xml -XPath $currentPath -Xml $xml -Namespace $Namespace;
                
                # check wether the child node already exists?
                if ( ($currentNode.Node.GetElementsByTagName($nodeTag, $nodeNamespaceURI).Count -eq 0) -and ( !$currentNode.Node.GetAttribute($nodeTag, $nodeNamespaceURI) ) ) {
                    # Create Child Node
                    if ( ($node -match "^@") -or ($nodeTag -match "^@") ) { # Create Attribute
                        
                        $attributeName = $nodeTag -replace "^@" ;
                        $newAttribute = $xml.CreateAttribute($nodeNamespacePrefix, $attributeName, $nodeNamespaceURI);
                        
                        $currentNode.Node.SetAttributeNode($newAttribute);
                        $isAttributeSet = $true;
                    } elseif ( $nodeTag -match "\[([0-9]+)\]" ) {  # Create Sibling Element
                        $nodeTag = $node -replace "\[([0-9]+)\]";
                        [int]$numberofnode = $Matches[1]
                        $currentNodeCount = $currentNode.Node.$nodeTag.Count;

                        For ( $i = $currentNodeCount+1; $i -le $numberofnode; $i++ ) {
                            $newElement = $xml.CreateElement($nodeNamespacePrefix, $nodeTag, $nodeNamespaceURI);
                            $currentNode.Node.AppendChild($newElement);
                        }
                    } elseif ( $nodeTag -eq "text()" ) {  # Create Text Node
                        $newTextNode = $xml.CreateTextNode($value);
                        $currentNode.Node.AppendChild($newTextNode);
                    } else { # Create Element
                        $newElement = $xml.CreateElement($nodeNamespacePrefix, $nodeTag, $nodeNamespaceURI);
                        $currentNode.Node.AppendChild($newElement);
                    } 
                    $sthNeededToBeCreated = $true;
                }
          }
          $currentPath += "/$node";
        
          }
        }
    }

    $currentNode = Select-Xml -XPath $Xpath -Xml $xml -Namespace $Namespace;
    if ( $currentNode ) {
        if ( ($Operation -eq "Update") -or ($Operation -eq "Replace") -or ( $Operation -eq "Create" -and $sthNeededToBeCreated -eq $true ) ) {
        
        
        #### Continue here: Text needs to be inserted correctly
            switch  ( $currentNode.Node.NodeType ) {
                "Element" {
                    $currentNode.Node.InnerXml = $value;
                }
                "Text" {
                    $currentNode.Node.InnerText = $value;
                }
                "Attribute" {
                    $currentNode.Node.InnerText = $value;
                }
            }
        } elseif ( $Operation -eq "Delete" ) {
            if ($currentNode.Node -is [System.Xml.XmlAttribute]) {
                $parentNode = $currentNode.Node.get_OwnerElement();
                $parentNode.RemoveAttribute($currentNode.Node);
            } else {
                $parentNode = $currentNode.Node.get_ParentNode();
                $parentNode.RemoveChild($currentNode.Node);
            }
        } 
        
    }
}

function Invoke-XmlRemediation {
<#
.SYNOPSIS
    Detects and remediates missmatches in xml
.DESCRIPTION
    This function takes a ruleset and matches it against a given xml document. If the function runs in remediation mode the xml content will be modified according to the ruleset.
.PARAMETER Action
    Defines wether the function will just detect missmatches or remediates them.
.PARAMETER FilePath
    The path to the xml file you want to test and remediate.
.PARAMETER Encoding
    The encoding of the xml file in case it needs to be created.
.PARAMETER Rules
    The set of remediation rules you want to match against the xml document.
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

    #try {
            if ( Test-Path -Path $FilePath ) {
                $encoding = Get-FileEncoding -Path $FilePath;
                [xml]$Xml = Get-Content -Path $FilePath -Encoding $encoding;
            } else {
                [xml]$Xml = "";
                $fileDoesNotExistYet = $true;
            }

            if ( ($fileDoesNotExistYet -eq $true -and $Operation -eq "create") -or ($fileDoesNotExistYet -eq $false -and $Operation -eq "update") -or ($Operation -eq "replace") ) {
                ForEach ( $rule in $Rules ) {
                    if ( !(Test-XPathValueOnContent -Xml $Xml -XPath $rule.XPath -Value $rule.Value -Namespace $rule.Namespace) ) {
                        $Compliance = "Non-Compliant: Element Missmatch."
                        if ($Operation -ne "replace") {
                            Set-XmlNodeByXpath -Xml $Xml -Xpath $rule.XPath -value $rule.Value -Operation $rule.Operation -Namespace $rule.Namespace;
                        }
                    }
                }
                if ( ($Compliance -ne "Compliant") -and ($Action -eq "Remediate") ) {
                    # If operation is replace the file should be recreated from scratch.
                    if ($Operation -eq "replace") {
                        [xml]$Xml = "";
                        ForEach ( $rule in $Rules ) {
                            Set-XmlNodeByXpath -Xml $Xml -Xpath $rule.XPath -value $rule.Value -Operation $rule.Operation -Namespace $rule.Namespace;
                        }
                    }

                    if ( !(Test-Path -Path "$Filepath\..") ) {
                        New-Item -Path $Filepath\.. -ItemType Directory
                    }
                    Out-File -FilePath $FilePath -InputObject $xml.OuterXml -Encoding $encoding -Force
                }
            }
      #  } catch {
       #     Write-Host "OHOH!"
      #          $compliance = "Non-Compliant: Unknown error occured"
       # }
       return $Compliance
}

# Given a [System.Xml.XmlNode] instance, returns the path to it
# inside its document in XPath form.
# Supports element, attribute, and text/CDATA nodes.
function Get-NodeXPath {
  param (
      [ValidateNotNull()]
      [System.Xml.XmlNode] $node
  )

  if ($node -is [System.Xml.XmlDocument]) { return '' } # Root reached
  $isAttrib = $node -is [System.Xml.XmlAttribute]

  # IMPORTANT: Use get_*() accessors for all type-native property access,
  #            to prevent name collision with Powershell's adapted-DOM ETS properties.
  $name = "";
  if ( $node.NamespaceURI ) {
    if ( !($node.GetPrefixOfNamespace($node.NamespaceURI)) ) {
        $name += "__Default__:"
    }
  }

  # Get the node's name.
  $name += if ($isAttrib) {
      '@' + $node.get_Name()
    } elseif ($node -is [System.Xml.XmlText] -or $node -is [System.Xml.XmlCDataSection]) {
      'text()'
    } else { # element
      $node.get_Name()
    }



  # Count any preceding siblings with the same name.
  # Note: To avoid having to provide a namespace manager, we do NOT use
  #       an XPath query to get the previous siblings.
  $prevSibsCount = 0; $prevSib = $node.get_PreviousSibling()
  while ($prevSib) {
    if ($prevSib.get_Name() -ceq $name) { ++$prevSibsCount }
    $prevSib = $prevSib.get_PreviousSibling()
  }

  # Determine the (1-based) index among like-named siblings, if applicable.
  $ndx = if ($prevSibsCount) { '[{0}]' -f (1 + $prevSibsCount) }

  # Determine the owner / parent element.
  $ownerOrParentElem = if ($isAttrib) { $node.get_OwnerElement() } else { $node.get_ParentNode() }

  # Recurse upward and concatenate with "/"
  "{0}/{1}" -f (Get-NodeXPath $ownerOrParentElem), ($name + $ndx)
}

function Get-NodeNamespaces {
  param (
      [ValidateNotNull()]
      [System.Xml.XmlNode] $node
  )

  $namespace = @{}

  do {
  

  $isAttrib = $node -is [System.Xml.XmlAttribute]



  if (!($node -is [System.Xml.XmlText] -or $node -is [System.Xml.XmlCDataSection])) {
    $namespaceURI = $node.NamespaceURI
    if ( $namespaceURI ) {
        $namespacePrefix = $node.GetPrefixOfNamespace($namespaceURI)

        if ( $namespacePrefix -eq "" ) {
            $namespacePrefix = "__Default__";
        }
        $namespace[$namespacePrefix] = $namespaceURI;
    }
  }

  $node = if ($isAttrib) { $node.get_OwnerElement() } else { $node.get_ParentNode() }
  } while (!($node -is [System.Xml.XmlDocument]))

  return $namespace;
}

# SIG # Begin signature block
# MIIWYAYJKoZIhvcNAQcCoIIWUTCCFk0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUD/dK2wfI4Hks3BMFIktgmMSj
# zhugghBKMIIE3DCCA8SgAwIBAgIRAP5n5PFaJOPGDVR8oCDCdnAwDQYJKoZIhvcN
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUYzIonQ5R7pSzQkB+f2gA
# 0pAsMmUwDQYJKoZIhvcNAQEBBQAEggEAdCNBVbHq8dppEVRPQ6lcmaxiefZ3sYD5
# QYvOh5o6sam8pi3uPbFFvQ/5Zyd22vl3ywe5YrkWqR8Jf+VM3LlShCKmXDyylZD2
# sJnzoGEL2Rl4LbTWmG7L3HFGCINpNIS1ONbhvoIjXTXoe8nk7fkVts3NzkODW+BV
# Jqy0qSciI21k67iDKCr30xmaccIYMb8AHCZT4Bo+nT/eUl7RMWc/nNAU42fVCNR7
# nqehi6aGh1+g3pAbOOY1uZqlSgGmCpTMBVTDZroxzMAwvasVxGp3YWsxg/RwR7jn
# QJqj5fWOp+X65g1KoQN42feQWDmJAw+d5RUhWM4hcRYmSvuEq632YaGCA0gwggNE
# BgkqhkiG9w0BCQYxggM1MIIDMQIBATCBkzB+MQswCQYDVQQGEwJQTDEiMCAGA1UE
# ChMZVW5pemV0byBUZWNobm9sb2dpZXMgUy5BLjEnMCUGA1UECxMeQ2VydHVtIENl
# cnRpZmljYXRpb24gQXV0aG9yaXR5MSIwIAYDVQQDExlDZXJ0dW0gVHJ1c3RlZCBO
# ZXR3b3JrIENBAhEA/mfk8Vok48YNVHygIMJ2cDANBglghkgBZQMEAgEFAKCCAXIw
# GgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yMTAz
# MzExODU5NDlaMC8GCSqGSIb3DQEJBDEiBCCxilcBrSGbzCa4h3Uj9P61oQV9avq1
# 1H86H+22+yx6sTA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDZyqvDIltwMM24PjhG
# 42kcFO15CxdkzhtPBDFXiZxcWDCBywYLKoZIhvcNAQkQAgwxgbswgbgwgbUwgbIE
# FE+NTEgGSUJq74uG1NX8eTLnFC2FMIGZMIGDpIGAMH4xCzAJBgNVBAYTAlBMMSIw
# IAYDVQQKExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0
# dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVz
# dGVkIE5ldHdvcmsgQ0ECEQD+Z+TxWiTjxg1UfKAgwnZwMA0GCSqGSIb3DQEBAQUA
# BIIBAKSTtiW6jUQAy+2qqf93TfDv8TRYyGIjWDUXo1qLup6z8fv2iztWHYUVcg9Y
# Gn+RHjEZMhvjDWlrkL0vS5iu8UfG3jqqAwJZhoCWHYdQBcicD/pm3WXgnyEwYH32
# Eat6OZ0/Q2/NNI13ERa+ZZGE/aIN9YbrvtH6QUAjIRK9UHYQuYb2A498iHRsfzDp
# bjwhRxlQNr3msIMz3l6iQICSocFm4KDBe6ytp0Crni49LXVzOS7bh2jXFLHkkWzK
# 3GXVozoAgQqgFRaH2mh+NXVHgrfds8U1s3D3l5CwXGWRWmgZLzbEJGvo4cVwNH6x
# uL4E20j/dD0AagI7MU8us3QyWzk=
# SIG # End signature block
