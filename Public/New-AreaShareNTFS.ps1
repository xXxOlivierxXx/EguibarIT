function New-AreaShareNTFS
{
    <#
        .Synopsis
            Function to create a new Area folder share
        .DESCRIPTION
            Function to create a new Area folder share
        .EXAMPLE
            New-AreaShareNTFS -ShareName 'Acounting' -ReadGroup 'SL_Accounting_Read' -ChangeGroup 'SL_Accounting_write' -SiteAdminGroup 'SG_Accounting_MNGT' -SitePath 'C:\Shares\Areas\Accounting'
        .INPUTS
            Param1...: ShareName
            Param2...: ReadGroup
            Param3...: ChangeGroup
            Param4...: SiteAdminGroup
            Param5...: SitePath
        .NOTES
            Version:         1.1
            DateModified:    03/Oct/2016
            LasModifiedBy:   Vicente Rodriguez Eguibar
                vicente@eguibar.com
                Eguibar Information Technology S.L.
                http://www.eguibarit.com
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([String])]
    Param
    (
        # Param1 Sharename
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'Name of the share to be created',
        Position = 0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ShareName,

        # Param2 Read group
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'Name of the group with Read-Only permissions',
        Position = 1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $readGroup,

        # Param3 Change Group
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'Name of the group with Change permissions',
        Position = 2)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $changeGroup,

        # Param4 All Site Admins group
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'Name of the group with Full permissions',
        Position = 3)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SG_SiteAdminsGroup,

        # Param5 Path to the site
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'DistinguishedName where the new Groups will be created.',
        Position = 4)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $sitePath,
        
        # Param6
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'Absolute path to the root Share folder (e.g. "C:\Shares\")',
        Position = 5)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ShareLocation,
                
        # Param7
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $false,
            HelpMessage = 'The root share name for general areas.',
        Position = 6)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]
        $AreasName
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

        
        #------------------------------------------------------------------------------
        # Define the variables

        # Create Full Share Name
        $FullShareName = '{0}\{1}\{2}' -f $PSBoundParameters['ShareLocation'], $PSBoundParameters['AreasName'], $PSBoundParameters['ShareName']

        $parameters = $null

        # END variables
        #---------------------
    }

    Process
    {
        If(-not(test-path -Path $FullShareName))
        {
            # Create the new Directory
            New-Item -Path $FullShareName -ItemType Directory
        }

        # Create the associated READ group
        $parameters = @{
            Name                          = $PSBoundParameters['readGroup']
            GroupCategory                 = 'Security'
            GroupScope                    = 'DomainLocal'
            DisplayName                   = $PSBoundParameters['readGroup']
            Path                          = $PSBoundParameters['sitePath']
            Description                   = 'Read Access to Share {0}' -f $PSBoundParameters['ShareName']
        }
        New-AdDelegatedGroup @parameters

        # Create the associated Modify group
        $parameters = @{
            Name                          = $PSBoundParameters['changeGroup']
            GroupCategory                 = 'Security'
            GroupScope                    = 'DomainLocal'
            DisplayName                   = $PSBoundParameters['changeGroup']
            Path                          = $PSBoundParameters['sitePath']
            Description                   = 'Read Access to Share {0}' -f $PSBoundParameters['ShareName']
        }
        New-AdDelegatedGroup @parameters

        Start-Sleep -Seconds 2

        Grant-NTFSPermissions -path $FullShareName -object $PSBoundParameters['readGroup'] -permission 'ReadAndExecute, ChangePermissions'
        Grant-NTFSPermissions -path $FullShareName -object $PSBoundParameters['changeGroup'] -permission 'Modify, ChangePermissions'
        Grant-NTFSPermissions -path $FullShareName -object $PSBoundParameters['SG_SiteAdminsGroup'] -permission 'FullControl, ChangePermissions'

        #& "$env:windir\system32\net.exe" share $ShareName=$FullShareName '/GRANT:Everyone,FULL'
        
        New-SmbShare -Name $PSBoundParameters['ShareName'] -Path $FullShareName -FullAccess Everyone
        
        if ($error.count -eq 0)
        {
            Write-Verbose -Message ('The folder {0} was shared correctly.' -f $ShareName)
        }
    }
    End
    {
        Write-Verbose -Message "Function $($MyInvocation.InvocationName) finished creating the share."
        Write-Verbose -Message ''
        Write-Verbose -Message '-------------------------------------------------------------------------------'
        Write-Verbose -Message ''
    }
}