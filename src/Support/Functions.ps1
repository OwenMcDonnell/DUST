<# 
.EXTERNALHELP Connect-OnlineService-help.xml
#>
Function Connect-OnlineService {
    [CmdletBinding(DefaultParameterSetName='Direct')]
    Param (
        [Parameter(ParameterSetName='Direct',Mandatory,Position=0)]
        [Parameter(ParameterSetName='Delegated',Mandatory,Position=0)]
        [ValidateSet('MicrosoftOnline','AzureADv2','ExchangeOnline','SecurityAndComplianceCenter')]
        [String] $Service
    )

    DynamicParam {
        $services = @('MicrosoftOnline','AzureADv2','ExchangeOnline')

        if ($services -contains $Service) {
            # Delegated attribute
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $delegatedAttribute = New-Object System.Management.Automation.ParameterAttribute
            $delegatedAttribute.Position = 1
            $delegatedAttribute.ParameterSetName = 'Delegated'
            $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $attributeCollection.Add($delegatedAttribute)
            $delegatedParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Delegated', [Switch], $attributeCollection)
            $RuntimeParameterDictionary.Add('Delegated', $delegatedParam)

            # ClientDomain attribute
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $clientDomainAttribute = New-Object System.Management.Automation.ParameterAttribute
            $clientDomainAttribute.Position = 2
            $clientDomainAttribute.ParameterSetName = 'Delegated'
            $clientDomainAttribute.Mandatory = $true
            $attributeCollection.Add($clientDomainAttribute)
            $clientDomainParam = New-Object System.Management.Automation.RuntimeDefinedParameter('ClientDomain', [String], $attributeCollection)
            $RuntimeParameterDictionary.Add('ClientDomain', $clientDomainParam)

            # Credential
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $credentialAttribute = New-Object System.Management.Automation.ParameterAttribute
            $credentialAttribute.Position = 3
            $credentialAttribute.ParameterSetName = "Delegated"
            $credentialAttribute.Mandatory = $true
            $attributeCollection.Add($credentialAttribute)
            $credentialParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Credential', [PSCredential], $attributeCollection)
            $RuntimeParameterDictionary.Add('Credential', $credentialParam)

            return $RuntimeParameterDictionary
        }
    }

    Process {
        if ($PSBoundParameters.Delegated) {
            $cmd = Get-Command "Connect-$Service"
            & $cmd -Delegated -ClientDomain ($PSBoundParameters.ClientDomain) -Credential ($PSBoundParameters.Credential)
        } else {
            & (Get-Command "Connect-$Service")
        }
    }
}

Function Test-IsConnectedToService {
    [CmdletBinding()] Param (
        [ValidateSet('MicrosoftOnline','AzureADv2','ExchangeOnline','SecurityAndComplianceCenter')]
        [String] $Service
    )

    switch ($Service) {
        'MicrosoftOnline' {
            try {
                Get-MsolCompanyInformation
            } catch [Microsoft.Online.Administration.Automation.MicrosoftOnlineException] {
                Write-Error 'Not connected to Microsoft Online! Please run ''Connect-OnlineService MicrosoftOnline'' before using this command.'
            }
        }
        'AzureADv2' {
            try {
                Get-AzureADTenantDetail
            } catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] {
                Write-Error 'Not connected to Azure AD! Please run ''Connect-OnlineService AzureADv2'' before using this command.'
            }
        }
        'ExchangeOnline' {
            if (!(Get-PSSession | Where-Object { ($_.Name -like 'DUST-EXO' -or $_.ConfigurationName -like 'Microsoft.Exchange') -and $_.State -like 'Opened' })) {
                Write-Error 'Not connected to Exchange online! Please use ''Connect-OnlineService ExchangeOnline'' before using this command.'
            }
        }
        'SecurityAndComplianceCenter' {
            if (!(Get-PSSession | Where-Object { ($_.Name -like 'DUST-SCC' -or $_.ConfigurationName -like 'Microsoft.Exchange') -and $_.State -like 'Opened' })) {
                Write-Error 'Not connected to the Security and Compliance Center! Please use ''Connect-OnlineService SecurityAndComplianceCenter'' before using this command.'
            }
        }
    }

}

Function Remove-BrokenOrClosedDUSTPSSessions {
    [CmdletBinding()] Param ()

    Write-Verb "Checking for broken or closed connections..."
    $psBroken = Get-PSSession | where-object {$_.State -like "*Broken*" -and $_.Name -like "DUST-*"}
    $psClosed = Get-PSSession | where-object {$_.State -like "*Closed*" -and $_.Name -like "DUST-*"}

    if ($psBroken.count -gt 0)
    {
        for ($index = 0; $index -lt $psBroken.count; $index++)
        {
            Write-Verb "Removing broken session: $psBroken[$index].Name"
            Remove-PSSession -session $psBroken[$index]
        }
    }

    if ($psClosed.count -gt 0)
    {
        for ($index = 0; $index -lt $psClosed.count; $index++)
        {
            Write-Verb "Removing closed session: $psBroken[$index].Name"
            Remove-PSSession -session $psClosed[$index]
        }
    }
    Write-Verb "Done"
}

<# 
.EXTERNALHELP Install-DUSTDependencies-help.xml
#>
Function Install-DUSTDependencies {
    [CmdletBinding()] Param (
        [Parameter()]
        [Switch] $ListOnly
    )

    # WORK IN PROGRESS
    # This function currently doesn't operate properly, most code here was thrown down just so dependencies are documented somewhere

    if ($ListOnly) {
        Write-Output 'Please manually install the following dependencies:'
        Write-Output 'Exchange Online Remote PowerShell Module - https://docs.microsoft.com/en-us/powershell/exchange/exchange-online/connect-to-exchange-online-powershell/mfa-connect-to-exchange-online-powershell?view=exchange-ps'
        Write-Output 'Microsoft Online Services Sign-In Assistant for IT Professionals RTW (64-bit) - https://www.microsoft.com/en-us/download/details.aspx?id=28177'
        Write-Output 'Microsoft Online PowerShell Module - https://www.powershellgallery.com/packages/MSOnline'
        Write-Output 'Microsoft Azure AD PowerShell Module - https://www.powershellgallery.com/packages/AzureAD/2.0.2.4'
    } else {
        if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            # We are running as an admin
    
            $progressActivity = 'Installing Dependencies'
            $stepMax = 6
    
            Write-Progress -Id 1 -Activity $progressActivity -Status "Preparing" -PercentComplete 5
    
            if ($IsWindows -or $ENV:OS -like 'Windows_NT') {
                # Exchange Online Remote PowerShell Modul
                Write-Progress -Id 1 -Activity $progressActivity -Status "Step 1 of $stepMax" -CurrentOperation 'Installing Exchange Online PowerShell Module (ClickOnce)' -PercentComplete 10
                Install-ClickOnce -Manifest 'https://cmdletpswmodule.blob.core.windows.net/exopsmodule/Microsoft.Online.CSE.PSModule.Client.application'
    
                # Microsoft Online Services Sign-In Assistant for IT Professionals RTW (x64)
                Write-Progress -Id 1 -Activity $progressActivity -Status "Step 2 of $stepMax" -CurrentOperation 'Installing Microsoft Online Services Sign-In Assistant for IT Professionals (x64 MSI)' -PercentComplete 30
                Invoke-WebRequest -Uri 'https://download.microsoft.com/download/5/0/1/5017D39B-8E29-48C8-91A8-8D0E4968E6D4/en/msoidcli_64.msi' -UseBasicParsing -OutFile "$env:temp\msoidcli_64.msi"
                Start-Process -FilePath 'C:\Windows\System32\msiexec.exe' -ArgumentList '/qb /I', "$env:temp\msoidcli_64.msi" -WorkingDirectory "$env:temp" -Wait
            }
            
            Write-Progress -Id 1 -Activity $progressActivity -Status "Step 3 of $stepMax" -CurrentOperation 'Checking for Module: MSOnline' -PercentComplete 40
            # Azure AD v1
            if (!(Get-InstalledModule -Name 'MSOnline' -ErrorAction SilentlyContinue)) {
                Write-Progress -Id 1 -Activity $progressActivity -Status "Step 4 of $stepMax" -CurrentOperation 'Installing MSOnline Powershell Module' -PercentComplete 50
                Install-Module -Name 'MSOnline' -Force
            }
    
            Write-Progress -Id 1 -Activity $progressActivity -Status "Step 5 of $stepMax" -CurrentOperation 'Checking for Module: AzureAD' -PercentComplete 60
            # Azure AD v2
            if (!(Get-InstalledModule -Name 'AzureAD' -ErrorAction SilentlyContinue)) {
                Write-Progress -Id 1 -Activity $progressActivity -Status "Step 6 of $stepMax" -CurrentOperation 'Installing AzureAD Powershell Module' -PercentComplete 70
                Install-Module -Name 'AzureAD' -Force
            }
    
        } else {
            # We are not running as an admin
            Write-Error "You must be running Powershell as an administrator to install all dependencies."
        }
    }
}