Function New-TimePolicyGPO
{
    <#
        .Synopsis
            
        .DESCRIPTION
            
        .EXAMPLE
            New-TimePolicyGPO
        .INPUTS
            
        .NOTES
            Version:         1.0
            DateModified:    25/Mar/2014
            LasModifiedBy:   Vicente Rodriguez Eguibar
                vicente@eguibar.com
                Eguibar Information Technology S.L.
                http://www.eguibarit.com
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    Param
    (
        # Param1 GPO Name
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromRemainingArguments = $false,
            HelpMessage = 'Name of the GPO to be created',
        Position = 0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $gpoName,

        # Param2 NTP servers
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromRemainingArguments = $false,
            HelpMessage = 'NTP Servers to be used for time sync',
        Position = 1)]
        [string]
        $NtpServer,

        # Param3 AnnounceFlags for reliable time server
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromRemainingArguments = $false,
            HelpMessage = 'AnnounceFlags for reliable time server',
        Position = 2)]
        [ValidateNotNullOrEmpty()]
        [int]
        $AnnounceFlags,

        # Param4 Type of Sync
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromRemainingArguments = $false,
            HelpMessage = 'Type of sync to be used',
        Position = 3)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('NoSync', 'NTP', 'NT5DS', 'AllSync', ignorecase = $false)]
        [string]
        $Type,

        # Param5 WMIFilter to be created and used
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromRemainingArguments = $false,
            HelpMessage = 'WMIFilter to be created and used',
        Position = 3)]
        [ValidateNotNullOrEmpty()]
        $WMIFilter,

        # Param6 Disable Virtual Machine time sync clock
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromRemainingArguments = $false,
            HelpMessage = 'Disable Virtual Machine time sync clock',
        Position = 4)]
        [switch]
        $DisableVMTimeSync
    )

    Begin
    {
        Write-Verbose -Message '|=> ************************************************************************ <=|'
        Write-Verbose -Message (Get-Date).ToShortDateString()
        Write-Verbose -Message ('  Starting: {0}' -f $MyInvocation.Mycommand)  

        #display PSBoundparameters formatted nicely for Verbose output
        $NL   = "`n"  # New Line
        $HTab = "`t"  # Horizontal Tab
        [string]$pb = ($PSBoundParameters | Format-Table -AutoSize | Out-String).TrimEnd()
        Write-Verbose -Message "Parameters used by the function... $NL$($pb.split($NL).Foreach({"$($HTab*4)$_"}) | Out-String) $NL"



        $msWMIAuthor = (Get-ADUser -Identity $env:USERNAME).Name

        # Create WMI Filter
        $WMIGUID = [string]'{'+([Guid]::NewGuid())+'}'
        $WMIDN = 'CN='+$WMIGUID+',CN=SOM,CN=WMIPolicy,CN=System,{0}' -f ([ADSI]'LDAP://RootDSE').DefaultNamingContext.ToString()
        $WMICN = $WMIGUID
        $WMIdistinguishedname = $WMIDN
        $WMIID = $WMIGUID

        $now = (Get-Date).ToUniversalTime()
        $msWMICreationDate = ($now.Year).ToString('0000') + ($now.Month).ToString('00') + ($now.Day).ToString('00') + ($now.Hour).ToString('00') + ($now.Minute).ToString('00') + ($now.Second).ToString('00') + '.' + ($now.Millisecond * 1000).ToString('000000') + '-000'
        $msWMIName = $WMIFilter[0]
        $msWMIParm1 = $WMIFilter[1] + ' '
        $msWMIParm2 = '1;3;10;' + $WMIFilter[3].Length.ToString() + ';WQL;' + $WMIFilter[2] + ';' + $WMIFilter[3] + ';'

        # msWMI-Name: The friendly name of the WMI filter
        # msWMI-Parm1: The description of the WMI filter
        # msWMI-Parm2: The query and other related data of the WMI filter
        $Attr = @{
            'msWMI-Name'           = $msWMIName
            'msWMI-Parm1'          = $msWMIParm1
            'msWMI-Parm2'          = $msWMIParm2
            'msWMI-Author'         = $msWMIAuthor
            'msWMI-ID'             = $WMIID
            'instanceType'         = 4
            'showInAdvancedViewOnly' = 'TRUE'
            'distinguishedname'    = $WMIdistinguishedname
            'msWMI-ChangeDate'     = $msWMICreationDate
            'msWMI-CreationDate'   = $msWMICreationDate
        }
        
        $WMIPath = ('CN=SOM,CN=WMIPolicy,CN=System,{0}' -f ([ADSI]'LDAP://RootDSE').DefaultNamingContext.ToString())

        $ExistingWMIFilters = Get-ADObject -Filter 'objectClass -eq "msWMI-Som"' -Properties 'msWMI-Name', 'msWMI-Parm1', 'msWMI-Parm2'
        $array = @()
    }

    Process
    {
        If ($null -ne $ExistingWMIFilters)
        {
            foreach ($ExistingWMIFilter in $ExistingWMIFilters)
            {
                $array += $ExistingWMIFilter.'msWMI-Name'
            }
        }
        Else
        {
            $array += 'no filters'
        }

        if ($array -notcontains $msWMIName)
        {
            Write-Host -ForegroundColor Green ('Creating the {0} WMI Filter...' -f $msWMIName)
            $WMIFilterADObject = New-ADObject -name $WMICN -type 'msWMI-Som' -Path $WMIPath -OtherAttributes $Attr
        }
        Else
        {
            Write-Warning -Message ('The {0} WMI Filter already exists.' -f $msWMIName)
        }

        $WMIFilterADObject = $null

        # Get WMI filter
        $WMIFilterADObject = Get-ADObject -Filter 'objectClass -eq "msWMI-Som"' -Properties 'msWMI-Name', 'msWMI-Parm1', 'msWMI-Parm2' |
        Where-Object {
            $_.'msWMI-Name' -eq "$msWMIName"
        }

        $ExistingGPO = get-gpo -Name $PSBoundParameters['gpoName'] -ErrorAction 'SilentlyContinue'

        If ($null -eq $ExistingGPO)
        {
            Write-Host -ForegroundColor Green ('Creating the {0} Group Policy Object...' -f $PSBoundParameters['gpoName'])

            # Create new GPO shell
            $GPO = New-GPO -Name $PSBoundParameters['gpoName']

            # Disable User Settings
            $GPO.GpoStatus = 'UserSettingsDisabled'

            # Add the WMI Filter
            $GPO.WmiFilter = ConvertTo-WmiFilter $WMIFilterADObject

            # Set the three registry keys in the Preferences section of the new GPO
            $null = Set-GPPrefRegistryValue -Name $PSBoundParameters['gpoName'] -Action Update -Context Computer `
                -Key 'HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config' `
                -Type DWord -ValueName 'AnnounceFlags' -Value $PSBoundParameters['AnnounceFlags']

            $null = Set-GPPrefRegistryValue -Name $PSBoundParameters['gpoName'] -Action Update -Context Computer `
                -Key 'HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' `
                -Type String -ValueName 'NtpServer' -Value "$PSBoundParameters['NtpServer']"

            $null = Set-GPPrefRegistryValue -Name $PSBoundParameters['gpoName'] -Action Update -Context Computer `
                -Key 'HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' `
                -Type String -ValueName 'Type' -Value "$PSBoundParameters['Type']"

            If ($PSBoundParameters['DisableVMTimeSync'])
            {
                # Disable the Hyper-V time synchronization integration service.
                $null = Set-GPPrefRegistryValue -Name $PSBoundParameters['gpoName'] -Action Update -Context Computer `
                    -Key 'HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' `
                -Type DWord -ValueName 'Enabled' -Value 0

                # Used to control how often the time service synchronizes to 15 minutes
                $null = Set-GPPrefRegistryValue -Name $PSBoundParameters['gpoName'] -Action Update -Context Computer `
                    -Key 'HKLM\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient' `
                    -Type DWord -ValueName 'SpecialPollInterval' -Value 900

                # Set the three registry keys in the Preferences section of the new GPO
                $null = Set-GPPrefRegistryValue -Name $PSBoundParameters['gpoName'] -Action Update -Context Computer `
                    -Key 'HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config' `
                    -Type DWord -ValueName 'MaxPosPhaseCorrection' -Value 3600

                # Set the three registry keys in the Preferences section of the new GPO
                    $null = Set-GPPrefRegistryValue -Name $PSBoundParameters['gpoName'] -Action Update -Context Computer `
                    -Key 'HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config' `
                    -Type DWord -ValueName 'MaxNegPhaseCorrection' -Value 3600
            }#end if

            # Link the new GPO to the Domain Controllers OU
            Write-Host -ForegroundColor Green ('Linking the {0} Group Policy Object to the OU=Domain Controllers,{1} ...' -f $PSBoundParameters['gpoName'], ([ADSI]'LDAP://RootDSE').DefaultNamingContext.ToString())
            $null = New-GPLink -Name $PSBoundParameters['gpoName'] -Target ('OU=Domain Controllers,{0}' -f ([ADSI]'LDAP://RootDSE').DefaultNamingContext.ToString())
        }
        Else
        {
            Write-Warning -Message ('The {0} Group Policy Object already exists.' -f $PSBoundParameters['gpoName'])
            Write-Host -ForegroundColor Green ('Adding the {0} WMI Filter...' -f $msWMIName)
            $ExistingGPO.WmiFilter = ConvertTo-WmiFilter $WMIFilterADObject
        }
    }

    End
    {
        Write-Host -ForegroundColor Green "Completed.`n"
        Write-Verbose -Message "Function $($MyInvocation.InvocationName) finished creating the Time Policy GPO."
        Write-Verbose -Message ''
        Write-Verbose -Message '-------------------------------------------------------------------------------'
        Write-Verbose -Message ''
        
        $ObjectExists = $null
    }
}