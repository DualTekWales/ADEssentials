﻿function Test-LdapServer {
    [cmdletBinding()]
    param(
        [string] $ServerName,
        [string] $Computer,
        [PSCustomObject] $Advanced,
        [int] $GCPortLDAP = 3268,
        [int] $GCPortLDAPSSL = 3269,
        [int] $PortLDAP = 389,
        [int] $PortLDAPS = 636,
        [switch] $VerifyCertificate,
        [PSCredential] $Credential,
        [string] $Identity,
        [switch] $SkipCheckGC,
        [int] $RetryCount
    )
    $RetryCountList = [System.Collections.Generic.List[int]]::new()
    $ScriptRetryCount = $RetryCount
    $testLDAPPortsSplat = @{
        ServerName = $ServerName
        Port       = $GCPortLDAP
        Identity   = $Identity
    }
    if ($PSBoundParameters.ContainsKey('Credential')) {
        $testLDAPPortsSplat.Credential = $Credential
    }

    if (-not $SkipCheckGC) {
        if ($Advanced -and $Advanced.IsGlobalCatalog -or -not $Advanced) {
            # Test GC LDAP Port
            $testLDAPPortsSplat['Port'] = $GCPortLDAP
            # Reset RetryCount
            $RetryCount = $ScriptRetryCount
            Do {
                $GlobalCatalogNonSSL = Test-LDAPPorts @testLDAPPortsSplat
                if ($GlobalCatalogNonSSL.Status -eq $false) {
                    $RetryCount--
                    if ($RetryCount -le 0) {
                        break
                    }
                }
            } until ($GlobalCatalogNonSSL.Status -eq $true)
            $RetryCountList.Add($ScriptRetryCount - $RetryCount)
            #$GlobalCatalogNonSSL = Test-LDAPPorts @testLDAPPortsSplat
            # # Test GC LDAPS Port
            if ($ServerName -notlike '*.*') {
                # querying SSL won't work for non-fqdn, we check if after all our checks it's string with dot.
                $GlobalCatalogSSL = [PSCustomObject] @{ Status = $false; ErrorMessage = 'No FQDN' }
            } else {

                $testLDAPPortsSplat['Port'] = $GCPortLDAPSSL
                # Reset RetryCount
                $RetryCount = $ScriptRetryCount
                Do {
                    $GlobalCatalogSSL = Test-LDAPPorts @testLDAPPortsSplat
                    if ($GlobalCatalogSSL.Status -eq $false) {
                        $RetryCount--
                        if ($RetryCount -le 0) {
                            break
                        }
                    }
                } until ($GlobalCatalogSSL.Status -eq $true)
                $RetryCountList.Add($ScriptRetryCount - $RetryCount)
                #$GlobalCatalogSSL = Test-LDAPPorts @testLDAPPortsSplat

            }
        } else {
            $GlobalCatalogSSL = [PSCustomObject] @{ Status = $null; ErrorMessage = 'Not Global Catalog' }
            $GlobalCatalogNonSSL = [PSCustomObject] @{ Status = $null; ErrorMessage = 'Not Global Catalog' }
        }
    } else {
        $GlobalCatalogSSL = [PSCustomObject] @{ Status = $null; ErrorMessage = 'Not Global Catalog' }
        $GlobalCatalogNonSSL = [PSCustomObject] @{ Status = $null; ErrorMessage = 'Not Global Catalog' }
    }

    $testLDAPPortsSplat['Port'] = $PortLDAP
    # Reset RetryCount
    $RetryCount = $ScriptRetryCount
    Do {
        $ConnectionLDAP = Test-LDAPPorts @testLDAPPortsSplat
        if ($ConnectionLDAP.Status -eq $false) {
            $RetryCount--
            if ($RetryCount -le 0) {
                break
            }
        }
    } until ($ConnectionLDAP.Status -eq $true)
    $RetryCountList.Add($ScriptRetryCount - $RetryCount)
    #$ConnectionLDAP = Test-LDAPPorts @testLDAPPortsSplat

    if ($ServerName -notlike '*.*') {
        # querying SSL won't work for non-fqdn, we check if after all our checks it's string with dot.
        $ConnectionLDAPS = [PSCustomObject] @{ Status = $false; ErrorMessage = 'No FQDN' }
    } else {
        $testLDAPPortsSplat['Port'] = $PortLDAPS
        Do {
            $ConnectionLDAPS = Test-LDAPPorts @testLDAPPortsSplat
            if ($ConnectionLDAPS.Status -eq $false) {
                $RetryCount--
                if ($RetryCount -le 0) {
                    break
                }
            }
        } until ($ConnectionLDAPS.Status -eq $true)
        $RetryCountList.Add($ScriptRetryCount - $RetryCount)
        # $ConnectionLDAPS = Test-LDAPPorts @testLDAPPortsSplat
    }

    $PortsThatWork = @(
        if ($GlobalCatalogNonSSL.Status) { $GCPortLDAP }
        if ($GlobalCatalogSSL.Status) { $GCPortLDAPSSL }
        if ($ConnectionLDAP.Status) { $PortLDAP }
        if ($ConnectionLDAPS.Status) { $PortLDAPS }
    ) | Sort-Object

    $PortsIdentityStatus = @(
        if ($GlobalCatalogNonSSL.IdentityStatus) { $GCPortLDAP }
        if ($GlobalCatalogSSL.IdentityStatus) { $GCPortLDAPSSL }
        if ($ConnectionLDAP.IdentityStatus) { $PortLDAP }
        if ($ConnectionLDAPS.IdentityStatus) { $PortLDAPS }
    ) | Sort-Object

    $ListIdentityStatus = @(
        $GlobalCatalogSSL.IdentityStatus
        $GlobalCatalogNonSSL.IdentityStatus
        $ConnectionLDAP.IdentityStatus
        $ConnectionLDAPS.IdentityStatus
    )
    if ($ListIdentityStatus -contains $false) {
        $IsIdentical = $false
    } else {
        $IsIdentical = $true
    }

    if ($VerifyCertificate) {
        $testLDAPCertificateSplat = @{
            Computer = $ServerName
            Port     = $PortLDAPS
        }
        if ($PSBoundParameters.ContainsKey("Credential")) {
            $testLDAPCertificateSplat.Credential = $Credential
        }
        # Reset RetryCount
        $RetryCount = $ScriptRetryCount
        Do {
            $Certificate = Test-LDAPCertificate @testLDAPCertificateSplat
            if ($Certificate.State -eq $false) {
                $RetryCount--
                if ($RetryCount -le 0) {
                    break
                }
            }
        } until ($Certificate.State -eq $true)
        $RetryCountList.Add($ScriptRetryCount - $RetryCount)

        if (-not $SkipCheckGC) {
            if (-not $Advanced -or $Advanced.IsGlobalCatalog) {
                $testLDAPCertificateSplat['Port'] = $GCPortLDAPSSL
                # Reset RetryCount
                $RetryCount = $ScriptRetryCount
                Do {
                    $CertificateGC = Test-LDAPCertificate @testLDAPCertificateSplat
                    if ($CertificateGC.State -eq $false) {
                        $RetryCount--
                        if ($RetryCount -le 0) {
                            break
                        }
                    }
                } until ($CertificateGC.State -eq $true)
                $RetryCountList.Add($ScriptRetryCount - $RetryCount)
            } else {
                $CertificateGC = [PSCustomObject] @{ Status = 'N/A'; ErrorMessage = 'Not Global Catalog' }
            }
        }
    }

    if ($VerifyCertificate) {
        $Output = [ordered] @{
            Computer                = $ServerName
            Site                    = $Advanced.Site
            IsRO                    = $Advanced.IsReadOnly
            IsGC                    = $Advanced.IsGlobalCatalog
            StatusDate              = $null
            StatusPorts             = $null
            StatusIdentity          = $null
            AvailablePorts          = $PortsThatWork -join ','
            X509NotBeforeDays       = $null
            X509NotAfterDays        = $null
            X509DnsNameList         = $null
            GlobalCatalogLDAP       = $GlobalCatalogNonSSL.Status
            GlobalCatalogLDAPS      = $GlobalCatalogSSL.Status
            GlobalCatalogLDAPSBind  = $null
            LDAP                    = $ConnectionLDAP.Status
            LDAPS                   = $ConnectionLDAPS.Status
            LDAPSBind               = $null

            Identity                = $Identity
            IdentityStatus          = $IsIdentical
            IdentityAvailablePorts  = $PortsIdentityStatus -join ','
            IdentityData            = $null
            IdentityErrorMessage    = $null

            IdentityGCLDAP          = $GlobalCatalogNonSSL.IdentityStatus
            IdentityGCLDAPS         = $GlobalCatalogSSL.IdentityStatus
            IdentityLDAP            = $ConnectionLDAP.IdentityStatus
            IdentityLDAPS           = $ConnectionLDAPS.IdentityStatus

            OperatingSystem         = $Advanced.OperatingSystem
            IPV4Address             = $Advanced.IPV4Address
            IPV6Address             = $Advanced.IPV6Address
            X509NotBefore           = $null
            X509NotAfter            = $null
            AlgorithmIdentifier     = $null
            CipherStrength          = $null
            X509FriendlyName        = $null
            X509SendAsTrustedIssuer = $null
            X509SerialNumber        = $null
            X509Thumbprint          = $null
            X509SubjectName         = $null
            X509Issuer              = $null
            X509HasPrivateKey       = $null
            X509Version             = $null
            X509Archived            = $null
            Protocol                = $null
            Hash                    = $null
            HashStrength            = $null
            KeyExchangeAlgorithm    = $null
            ExchangeStrength        = $null
            ErrorMessage            = $null
            RetryCount              = $RetryCountList -join ','
        }
    } else {
        $Output = [ordered] @{
            Computer               = $ServerName
            Site                   = $Advanced.Site
            IsRO                   = $Advanced.IsReadOnly
            IsGC                   = $Advanced.IsGlobalCatalog
            StatusDate             = $null
            StatusPorts            = $null
            StatusIdentity         = $null
            AvailablePorts         = $PortsThatWork -join ','
            GlobalCatalogLDAP      = $GlobalCatalogNonSSL.Status
            GlobalCatalogLDAPS     = $GlobalCatalogSSL.Status
            GlobalCatalogLDAPSBind = $null
            LDAP                   = $ConnectionLDAP.Status
            LDAPS                  = $ConnectionLDAPS.Status
            LDAPSBind              = $null
            Identity               = $Identity
            IdentityStatus         = $IsIdentical
            IdentityAvailablePorts = $PortsIdentityStatus -join ','
            IdentityData           = $null
            IdentityErrorMessage   = $null

            OperatingSystem        = $Advanced.OperatingSystem
            IPV4Address            = $Advanced.IPV4Address
            IPV6Address            = $Advanced.IPV6Address
            RetryCount             = $RetryCountList -join ','
        }
    }
    if ($VerifyCertificate) {
        $Output['LDAPSBind'] = $Certificate.State
        $Output['GlobalCatalogLDAPSBind'] = $CertificateGC.State
        $Output['X509NotBeforeDays'] = $Certificate['X509NotBeforeDays']
        $Output['X509NotAfterDays'] = $Certificate['X509NotAfterDays']
        $Output['X509DnsNameList'] = $Certificate['X509DnsNameList']
        $Output['X509NotBefore'] = $Certificate['X509NotBefore']
        $Output['X509NotAfter'] = $Certificate['X509NotAfter']
        $Output['AlgorithmIdentifier'] = $Certificate['AlgorithmIdentifier']
        $Output['CipherStrength'] = $Certificate['CipherStrength']
        $Output['X509FriendlyName'] = $Certificate['X509FriendlyName']
        $Output['X509SendAsTrustedIssuer'] = $Certificate['X509SendAsTrustedIssuer']
        $Output['X509SerialNumber'] = $Certificate['X509SerialNumber']
        $Output['X509Thumbprint'] = $Certificate['X509Thumbprint']
        $Output['X509SubjectName'] = $Certificate['X509SubjectName']
        $Output['X509Issuer'] = $Certificate['X509Issuer']
        $Output['X509HasPrivateKey'] = $Certificate['X509HasPrivateKey']
        $Output['X509Version'] = $Certificate['X509Version']
        $Output['X509Archived'] = $Certificate['X509Archived']
        $Output['Protocol'] = $Certificate['Protocol']
        $Output['Hash'] = $Certificate['Hash']
        $Output['HashStrength'] = $Certificate['HashStrength']
        $Output['KeyExchangeAlgorithm'] = $Certificate['KeyExchangeAlgorithm']
        $Output['ExchangeStrength'] = $Certificate['ExchangeStrength']
        $Output['ErrorMessage'] = $Certificate['ErrorMessage']
    } else {
        $Output.Remove('LDAPSBind')
        $Output.Remove('GlobalCatalogLDAPSBind')
    }
    if ($Identity) {
        $Output['IdentityData'] = $ConnectionLDAP.IdentityData
        $Output['IdentityErrorMessage'] = $ConnectionLDAP.IdentityErrorMessage
    } else {
        $Output.Remove('Identity')
        $Output.Remove('IdentityStatus')
        $Output.Remove('IdentityAvailablePorts')
        $Output.Remove('IdentityData')
        $Output.Remove('IdentityErrorMessage')
        $Output.Remove('IdentityGCLDAP')
        $Output.Remove('IdentityGCLDAPS')
        $Output.Remove('IdentityLDAP')
        $Output.Remove('IdentityLDAPS')
    }
    if (-not $Advanced) {
        $Output.Remove('IPV4Address')
        $Output.Remove('OperatingSystem')
        $Output.Remove('IPV6Address')
        $Output.Remove('Site')
        $Output.Remove('IsRO')
        $Output.Remove('IsGC')
    }
    # lets return the objects if required
    if ($Extended) {
        $Output['GlobalCatalogSSL'] = $GlobalCatalogSSL
        $Output['GlobalCatalogNonSSL'] = $GlobalCatalogNonSSL
        $Output['ConnectionLDAP'] = $ConnectionLDAP
        $Output['ConnectionLDAPS'] = $ConnectionLDAPS
        $Output['Certificate'] = $Certificate
        $Output['CertificateGC'] = $CertificateGC
    }

    if (-not $VerifyCertificate) {
        $StatusDate = 'Not available'
    } elseif ($VerifyCertificate -and $Output.X509NotAfterDays -lt 0) {
        $StatusDate = 'Failed'
    } else {
        $StatusDate = 'OK'
    }

    if ($Output.IsGC) {
        if ($Output.GlobalCatalogLDAP -eq $true -and $Output.GlobalCatalogLDAPS -eq $true -and $Output.LDAP -eq $true -and $Output.LDAPS -eq $true) {
            if ($VerifyCertificate) {
                if ($Output.LDAPSBind -eq $true -and $Output.GlobalCatalogLDAPSBind -eq $true) {
                    $StatusPorts = 'OK'
                } else {
                    $StatusPorts = 'Failed'
                }
            } else {
                $StatusPorts = 'OK'
            }
        } else {
            $StatusPorts = 'Failed'
        }
    } else {
        if ($Output.LDAP -eq $true -and $Output.LDAPS -eq $true) {
            if ($VerifyCertificate) {
                if ($Output.LDAPSBind -eq $true) {
                    $StatusPorts = 'OK'
                } else {
                    $StatusPorts = 'Failed'
                }
            } else {
                $StatusPorts = 'OK'
            }
        } else {
            $StatusPorts = 'Failed'
        }
    }
    if ($null -eq $Output.IdentityStatus) {
        $StatusIdentity = 'Not available'
    } elseif ($Output.IdentityStatus -eq $true) {
        $StatusIdentity = 'OK'
    } else {
        $StatusIdentity = 'Failed'
    }
    $Output['StatusDate'] = $StatusDate
    $Output['StatusPorts'] = $StatusPorts
    $Output['StatusIdentity'] = $StatusIdentity

    [PSCustomObject] $Output
}