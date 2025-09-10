
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


function Get-ADMXPolicyForRegistry {
    param(
        [string]$CategoryName,
        [string]$PolicyName,
        [string]$Class,
        [string]$Key,
        [string]$ValueName,
        [string]$DataType
    );

    $PolicyNameXMLCompatible = ConvertTo-XmlCompatibleString $PolicyName;
    $ValueNameXMLCompatible = ConvertTo-XmlCompatibleString $ValueName;
    $ClassXmlCompatible = ConvertTo-XmlCompatibleString $Class;
    $KeyXmlCompatible = ConvertTo-XmlCompatibleString $Key;
    $CategoryNameXmlCompatible = ConvertTo-XmlCompatibleString $CategoryName;

    switch ( $DataType ) {
        "String" {
            $element = '<text id="'+$PolicyNameXMLCompatible+'-value" valueName="'+$ValueNameXMLCompatible+'" required="true"/>'
        }
        "DWord" {
            $element = '<decimal id="'+$PolicyNameXMLCompatible+'-value" valueName="'+$ValueNameXMLCompatible+'" required="true"/>'
        }
        "MultiString" {
    		 $element = '<multiText id="'+$PolicyNameXMLCompatible+'-value" valueName="'+$ValueNameXMLCompatible+'" required="true"/>'
        }
    }
		$policy = '
<!-- Policy '+$PolicyName+' -->
<policy name="'+$PolicyNameXMLCompatible+'" class="'+$ClassXmlCompatible+'" displayName="$(string.Nothing)" explainText="$(string.Nothing)" key="'+$KeyXmlCompatible+'" valueName="'+$ValueNameXMLCompatible+'" >
	<parentCategory ref="'+$CategoryNameXmlCompatible+'" />
	<supportedOn ref="SupportedOn" />
	<elements>'+$element+'</elements>
</policy>
'
        return $policy;
}


function Get-ADMXPolicyForList {
    param(
        [string]$CategoryName,
        [string]$PolicyName,
        [string]$Class,
        [string]$Key
    );
    $CategoryNameXmlCompatible = ConvertTo-XmlCompatibleString $CategoryName;
    $PolicyNameXMLCompatible = ConvertTo-XmlCompatibleString $PolicyName;
    $ClassXmlCompatible = ConvertTo-XmlCompatibleString $Class;
    $KeyXmlCompatible = ConvertTo-XmlCompatibleString $Key;
    


		$policy = '
<!-- Policy '+$PolicyNameXMLCompatible+' -->
<policy name="'+$PolicyNameXMLCompatible+'" class="'+$ClassXmlCompatible+'" displayName="$(string.Nothing)" explainText="$(string.Nothing)" key="'+$KeyXmlCompatible+'" valueName="value" >
	<parentCategory ref="'+$CategoryNameXmlCompatible+'" />
	<supportedOn ref="SupportedOn" />
	<elements>
	<enum id="'+$PolicyNameXMLCompatible+'-operation" valueName="operation" required="true">
        <item displayName="$(string.Nothing)">
            <value>
                <string>Replace</string>
            </value>
        </item>
    </enum>
		<list id="'+$PolicyNameXMLCompatible+'-list" key="'+$KeyXmlCompatible+'\list"/>
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
    $CategoryNameXmlCompatible = ConvertTo-XmlCompatibleString $CategoryName;
    $PolicyNameXMLCompatible = ConvertTo-XmlCompatibleString $PolicyName;
    $ClassXmlCompatible = ConvertTo-XmlCompatibleString $Class;
    $KeyXmlCompatible = ConvertTo-XmlCompatibleString $Key;

		$policy = '
<!-- Policy '+$PolicyNameXMLCompatible+' -->
<policy name="'+$PolicyNameXMLCompatible+'" class="'+$ClassXmlCompatible+'" displayName="$(string.Nothing)" explainText="$(string.Nothing)" key="'+$KeyXmlCompatible+'" valueName="value" >
	<parentCategory ref="'+$CategoryNameXmlCompatible+'" />
	<supportedOn ref="SupportedOn" />
	<elements>
	<enum id="'+$PolicyNameXMLCompatible+'-operation" valueName="operation" required="true">
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
		<text id="'+$PolicyNameXMLCompatible+'-section" maxLength="255" valueName="section" required="true"/>
		<text id="'+$PolicyNameXMLCompatible+'-key" maxLength="255" valueName="key" required="true"/>
		<text id="'+$PolicyNameXMLCompatible+'-value" maxLength="255" valueName="value" required="true"/>
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

    $CategoryNameXmlCompatible = ConvertTo-XmlCompatibleString $CategoryName;
    $PolicyNameXMLCompatible = ConvertTo-XmlCompatibleString $PolicyName;
    $ClassXmlCompatible = ConvertTo-XmlCompatibleString $Class;
    $KeyXmlCompatible = ConvertTo-XmlCompatibleString $Key;

		$policy = '
<!-- Policy '+$PolicyNameXMLCompatible+' -->
<policy name="'+$PolicyNameXMLCompatible+'" class="'+$ClassXmlCompatible+'" displayName="$(string.Nothing)" explainText="$(string.Nothing)" key="'+$KeyXmlCompatible+'" valueName="value" >
	<parentCategory ref="'+$CategoryNameXmlCompatible+'" />
	<supportedOn ref="SupportedOn" />
	<elements>
	<enum id="'+$PolicyNameXMLCompatible+'-operation" valueName="operation" required="true">
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
		<list id="'+$PolicyNameXMLCompatible+'-namespace" key="'+$KeyXmlCompatible+'\namespace"/>
		<text id="'+$PolicyNameXMLCompatible+'-xpath" maxLength="255" valueName="xpath" required="true"/>
		<text id="'+$PolicyNameXMLCompatible+'-value" maxLength="255" valueName="value" required="true"/>
	</elements>
</policy>
'

        return $policy;
}



function Get-ADMXPolicyForJSon {
    param(
        [string]$CategoryName,
        [string]$PolicyName,
        [string]$Class,
        [string]$Key
    );

    $CategoryNameXmlCompatible = ConvertTo-XmlCompatibleString $CategoryName;
    $PolicyNameXMLCompatible = ConvertTo-XmlCompatibleString $PolicyName;
    $ClassXmlCompatible = ConvertTo-XmlCompatibleString $Class;
    $KeyXmlCompatible = ConvertTo-XmlCompatibleString $Key;

		$policy = '
<!-- Policy '+$PolicyNameXMLCompatible+' -->
<policy name="'+$PolicyNameXMLCompatible+'" class="'+$ClassXmlCompatible+'" displayName="$(string.Nothing)" explainText="$(string.Nothing)" key="'+$KeyXmlCompatible+'" valueName="value" >
	<parentCategory ref="'+$CategoryNameXmlCompatible+'" />
	<supportedOn ref="SupportedOn" />
	<elements>
	<enum id="'+$PolicyNameXMLCompatible+'-operation" valueName="operation" required="true">
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
		<text id="'+$PolicyNameXMLCompatible+'-jsonpath" maxLength="255" valueName="jsonpath" required="true"/>
		<text id="'+$PolicyNameXMLCompatible+'-value" maxLength="255" valueName="value" required="true"/>
        <text id="'+$PolicyNameXMLCompatible+'-datatype" maxLength="255" valueName="datatype" required="true"/>
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

    $AppNameXmlCompatible = ConvertTo-XmlCompatibleString $AppName;
    $AppPolicyNameXMLCompatible = ConvertTo-XmlCompatibleString $AppPolicyName;
    $FileTypeXmlCompatible = ConvertTo-XmlCompatibleString $FileType;
    $ClassXmlCompatible = ConvertTo-XmlCompatibleString $Class;

    $registryKey = Get-PolicyRegistryKey -AppName $AppNameXmlCompatible -AppPolicyName $AppPolicyNameXMLCompatible
    $PolicyName = "$AppNameXmlCompatible-$AppPolicyNameXMLCompatible-File"

$ADMXContent = '<?xml version="1.0" encoding="utf-8"?>
<!--
This ADMX-Template has been generated with a PolicyApplicator Applicator Conversion Kit
It is highly recommended that you review the generated content before deploying it.

Note that this template may only work when the PolicyApplicator Client is installed on the target system.
-->
<policyDefinitions xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" revision="1.0" xsi:schemaLocation="" schemaVersion="1.0" xmlns="http://www.microsoft.com/GroupPolicy/PolicyDefinitions" >
	<policyNamespaces >
		<target prefix="' + $AppNameXmlCompatible + '" namespace="'+$AppNameXmlCompatible+'.'+ $AppPolicyNameXMLCompatible +'.Policies" />
	</policyNamespaces>
	<resources minRequiredRevision="1.0" fallbackCulture="en-us" />
	<supportedOn >
		<definitions >
			<definition name="SupportedOn" displayName="$(string.Nothing)" />
		</definitions>
	</supportedOn>
	<categories >'+$categories+'</categories>
    <policies >
    <policy name="'+$PolicyName+'" class="'+$ClassXmlCompatible+'" displayName="$(string.Nothing)" explainText="$(string.Nothing)" key="'+$registryKey+'" valueName="Mode" >
	<parentCategory ref="'+$AppPolicyNameXMLCompatible+'" />
	<supportedOn ref="SupportedOn" />
        <enabledValue>
    <string>'+$FileTypeXmlCompatible+'</string>
    </enabledValue>
    <disabledValue>
        <string>Disabled</string>
    </disabledValue>
    <elements>
        <text id="'+$PolicyName+'-path" maxLength="255" valueName="path" required="true"/>
        <enum id="'+$PolicyName+'-operation" valueName="operation">
         <item displayName="$(string.Nothing)">
            <value>
                <string>create</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>update</string>
            </value>
        </item>
        <item displayName="$(string.Nothing)">
            <value>
                <string>replace</string>
            </value>
        </item>
        </enum>
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