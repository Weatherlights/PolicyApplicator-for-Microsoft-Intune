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

# Set-AuthenticodeSignature "C:\Users\hauke\GitHub\PolicyApplicator-for-Microsoft-Intune\Code\Modules\XMLFIle.psm1" @(Get-ChildItem cert:\CurrentUser\My -codesigning)[0] -TimestampServer http://time.certum.pl
# SIG # Begin signature block
# MIIlHAYJKoZIhvcNAQcCoIIlDTCCJQkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBjaMHavYZ9yBCN
# 1P4H0K1mEZVIf+WKPFwTg1+87eMhHqCCHikwggUJMIID8aADAgECAhANqkyYTw1Q
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
# AQkEMSIEIAOAEYCjnpqbMAU9wWvkzk1g8uRE6NflSoggis0QpbmWMA0GCSqGSIb3
# DQEBAQUABIIBANc8/rSGZvfTTOKf1QCeyy3WWz1jrIjngoEHfOpcQ9AM4YccI38X
# W6PNuULg+358NGLjFLzjBNdD8/xwUo3CaQi9GJc6QqUf0ogYcsX+ohmCdDu4ThuZ
# w4OTsD6fm8veEENd5xlmFf2OyrHzJJHXwVDHvXiRtUR/3RXuEieZBpB6KOzBqdT7
# xijl35i4n5nQa6w8FNZeEp1rEbeuYEDQ5MCbTkbzVyeZPYNTtM8T7tegNkOMEoY7
# KlP4Ep4iijSnLdIHu3+HjhUqRRemE5OaysxgzdDLPEYAbVY7WZdmu2C0CjAbx3N0
# mkqDcXzrxML4qDSteSc9d+nwfA3gdNk//HahggQCMIID/gYJKoZIhvcNAQkGMYID
# 7zCCA+sCAQEwajBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEg
# U3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0YW1waW5nIDIwMjEg
# Q0ECEAnFzPi7Zn1xN6rBWYAGyzEwDQYJYIZIAWUDBAICBQCgggFWMBoGCSqGSIb3
# DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjQwMzA3MjI1NDQ4
# WjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDqlUux0EC0MUBI2GWfj2FdiHQszOBn
# kuBWAk1LADrTHDA/BgkqhkiG9w0BCQQxMgQwcBQVomND2KS8OjWRuZPioXp25848
# htH1F9ixsFMnwNcouXhr3jJhET870ZtxzhEuMIGfBgsqhkiG9w0BCRACDDGBjzCB
# jDCBiTCBhgQUD0+4VR7/2Pbef2cmtDwT0Gql53cwbjBapFgwVjELMAkGA1UEBhMC
# UEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMb
# Q2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhAJxcz4u2Z9cTeqwVmABssxMA0G
# CSqGSIb3DQEBAQUABIICAAa1AaSvg4P4CmrnJvnf4HVEbQ3kYvoc7ULsNgwbZOsN
# 6e/CUWtr9l5G8/i09kNDQCaP68gua3fFvbhsqtKbj9aYB3IFBjcEltEbDgjGD1/s
# BoX0xB2F6FuD22mIhuBNirq+uh7WAX5EId3OkpP1DIOPhStx/0cB5NR+S5XK938r
# 6OrDf7Pr967uV1O1gVvjASh4kYEyoarmfLwAEphyh/SgU4IEPV+nSwGxcRJHhCBB
# B4+WW836QqsuWBB56uIixUTrE3W4jDAh7DTqA0GcSjZ9yg2P1h2gRuZpvlbNmYDK
# dgbxD8iF82d0nXrrDiOc/ULWrEbm00w7SVy82rc9NoQk5D7ESpllyaRmm4yad74K
# VMWk1wbPMI6qcr7Q0ydJpqh6fw6i9hFV8BXQ4caXcego7sAVWh1oN6qUomxGezBc
# tQeRjLizFGNQUq7Wg9GUGw+pPRq43FV1RaVnBFMRH1UYbv+rq8J0QDJwJyDPeTBz
# EGVlUTvpBR8pm3z4waly81s8PV+KZQMgYzP7mBiyCHHSxeaR6d8T5YRAKluOcMl8
# ALoPiuj8ugzvk+loKQxKanVbiT8dezRloS9IkraLaDYxbfK9ZUI4WuINf3r/yN17
# uVuwXnPa9pWHSKkpsZgHCVcjRPhecuIAEQGfqCeGEmmTSqR/08p8KMWL3GzsebN8
# SIG # End signature block
