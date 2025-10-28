Import-Module Az.Accounts
Import-Module Az.KeyVault
Import-Module PoshMailKit

# Variables
$subscriptionId     = "98d6ac31-3d59-42ab-99cd-f4dd44e9ba4c"
$tenantId           = "6d13c9cb-eb66-4cf1-b1c6-9ae7377847a9"
$resourceGroupName  = "sandbox-1"
$kvName             = "sandbox-1-keyvault"
$renewThresholdDays = 30

# Email settings
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$from = "tejas.s@aspentech.com"
$to = "tejas.s@aspentech.com"
$subject = "Azure Key Vault Secret Renewal Summary"
$credential = Get-AutomationPSCredential -Name "sandbox-automation-cred"

# Password generator function
function Generate-RandomPassword {
    param (
        [int]$length = 20,
        [int]$nonAlphaNumCount = 4
    )

    $alphaNumChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.ToCharArray()
    $specialChars = '!@#$%^&*()-_=+[]{}|;:,.<>?'.ToCharArray()

    $passwordChars = @()
    $passwordChars += (1..($length - $nonAlphaNumCount) | ForEach-Object { $alphaNumChars | Get-Random })
    $passwordChars += (1..$nonAlphaNumCount | ForEach-Object { $specialChars | Get-Random })

    $shuffledPassword = ($passwordChars | Get-Random -Count $passwordChars.Count) -join ''
    return $shuffledPassword
}

# Authenticate using Managed Identity
Connect-AzAccount -Identity
Set-AzContext -SubscriptionId $subscriptionId

# Get Key Vault
$kv = Get-AzKeyVault -VaultName $kvName -ResourceGroupName $resourceGroupName

# Get all secrets
$secrets = Get-AzKeyVaultSecret -VaultName $kvName
$updatedSecrets = @()

foreach ($secret in $secrets) {
    $secretName = $secret.Name
    $secretBundle = Get-AzKeyVaultSecret -VaultName $kvName -Name $secretName
    $expiryDate = $secretBundle.Attributes.Expires

    if ($expiryDate -and ((Get-Date).AddDays($renewThresholdDays) -ge $expiryDate)) {
        Write-Output "Secret '$secretName' is expiring on $expiryDate. Renewing..."

        $newSecretValue = Generate-RandomPassword
        $newExpiryDate = (Get-Date).AddYears(1)

        Set-AzKeyVaultSecret -VaultName $kvName -Name $secretName `
            -SecretValue (ConvertTo-SecureString $newSecretValue -AsPlainText -Force) `
            -Expires $newExpiryDate
        $updatedSecret = Get-AzKeyVaultSecret -VaultName $kvName -Name $secretName
        Write-Output "Post-update expiry: $($updatedSecret.Attributes.Expires)"
        Write-Output "Post-update value: $($updatedSecret.SecretValueText)"

        $updatedSecrets += [PSCustomObject]@{
            Name   = $secretName
            Expiry = $newExpiryDate.ToString("yyyy-MM-dd")
        }
    } else {
        Write-Output "Secret '$secretName' is valid until $expiryDate. No update needed."
    }
}

# Email Notification
if ($updatedSecrets.Count -gt 0) {
    $htmlTable = "<table border='1' cellpadding='5' cellspacing='0'><tr><th>Secret Name</th><th>New Expiration Date</th></tr>"
    foreach ($item in $updatedSecrets) {
        $htmlTable += "<tr><td>$($item.Name)</td><td>$($item.Expiry)</td></tr>"
    }
    $htmlTable += "</table>"

    $htmlBody = @"
<html>
<body>
<p>Hello Tejas,</p>
<p>The following secrets in Key Vault <b>'$kvName'</b> were renewed successfully:</p>
$htmlTable
<p>Regards,<br>Azure Automation</p>
</body>
</html>
"@
} else {
    $htmlBody = @"
<html>
<body>
<p>Hello Tejas,</p>
<p>No secrets in Key Vault <b>'$kvName'</b> required renewal at this time.</p>
<p>Regards,<br>Azure Automation</p>
</body>
</html>
"@
}

# Send email securely using PoshMailKit
Send-MKMailMessage -From $from -To $to -Subject $subject -Body $htmlBody `
    -BodyFormat Html -SmtpServer $smtpServer -Port $smtpPort -UseSsl `
    -Credential $credential -RequireSecureConnection