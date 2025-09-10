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