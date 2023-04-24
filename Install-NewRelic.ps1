###############################################################################################################
#This script deploys the New Relic Infrastructure agent and updates settings based on data in Active Directory#
###############################################################################################################
#It is assumed that this script will be executed on the target host by SCCM
#Configuration documentation: https://docs.newrelic.com/docs/infrastructure/install-infrastructure-agent/configuration/configure-infrastructure-agent/

####SECTION - GLOBAL####
#The powershell-yaml module is required.  The below line installs it from the powershell gallery with no prompts
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force   
Install-Module powershell-yaml -Force
#Get servername via the hostname command
$servername = hostname
#New Relic details go below
$apiKey = 'API KEY GOES HERE - secret manager recommended'
$accountID = 'New Relic AccountID goes here - secret manager recommended'
$region = 'New Relic Region here, US or EU'
# Define the YAML file path
$yamlConfigFilePath = "C:\Program Files\New Relic\newrelic-infra\newrelic-infra.yml"
####END SECTION####
####SECTION - INSTALL AGENT####
#Install the New Relic Agent using the guided install script
[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls'; $WebClient = New-Object System.Net.WebClient; $WebClient.DownloadFile("https://download.newrelic.com/install/newrelic-cli/scripts/install.ps1", "$env:TEMP\install.ps1"); & PowerShell.exe -ExecutionPolicy Bypass -File $env:TEMP\install.ps1;   $env:NEW_RELIC_API_KEY=$apiKey; $env:NEW_RELIC_ACCOUNT_ID=$accountId; $env:NEW_RELIC_REGION=$region; & 'C:\Program Files\New Relic\New Relic CLI\newrelic.exe' install -y
#Stop the New Relic service
Stop-Service newrelic-infra

####END SECTION####
####SECTION - CONFIGURATION####
#Install ActiveDiretory Module
Install-WindowsFeature -Name "RSAT-AD-Powershell"
Import-Module ActiveDirectory
# Get the AD computer object for the server
$computer = Get-ADComputer -Identity $servername -Properties *
$ou = Get-ADOrganizationalUnit -Identity $computer.DistinguishedName

# Check the newRelicConfig Attribute from the computer object in AD, and set the config file path as appropriate.  You could also you a group or OU, or attributes from those, to set this value
$newRelicConfigValue = $computer.newRelicConfig
if ($computer.newRelicConfig -eq "AppA") {
    $configFilePath = 'c:\temp\configA.yml'
} elseif ($computer.newRelicConfig -eq "AppB") {
    $configFilePath = 'c:\temp\configB.yml'
} else {
    Write-Error "Computer does not have a newRelicConfig attribute set, or it is not in the acceptable values. Value is $newRelicConfigValue"
}
#copy pre-built yaml file to the local config path
Copy-Item $configFilePath 
####END SECTION####
####SECTION - CUSTOM ATTRIBUTES####
# This section sets custom attributes (similar to tags) based on the computer object and the OU object
# Create an empty hashtable to store the tags.attributes
$attributes = @{}

# Add the computer object attributes to the hashtable
$attributes.Add("computerName", $computer.Name)
$attributes.Add("operatingSystem", $computer.OperatingSystem)
$attributes.Add("operatingSystemServicePack", $computer.OperatingSystemServicePack)

# Add the OU object attributes to the hashtable
$attributes.Add("ouName", $ou.Name)
$attributes.Add("ouDescription", $ou.Description)
$attributes.Add("ouDistinguishedName", $ou.DistinguishedName)

# Convert the hashtable to YAML format
$yamlAttributes = $attributes | ConvertTo-Yaml

# Add the text and attributes to the YAML file
$yamlText = @"
$textToAdd
custom_attributes:
  $yamlAttributes
"@

Add-Content -Path $yamlConfigFilePath -Value $yamlText

####END SECTION####
#Start the agent again
Start-Service newrelic-infra
