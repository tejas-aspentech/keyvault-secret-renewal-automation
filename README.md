## **Azure Key Vault Secret Renewal Automation**

### **Architecture**

<img width="912" height="684" alt="image" src="https://github.com/user-attachments/assets/da27d809-7f19-447c-beed-af00c1d101e1" />


**Flow Explanation:**

*   **Azure Automation Account** runs a PowerShell Runbook.
*   **Managed Identity** authenticates securely to Azure without credentials.
*   **Key Vault** stores secrets that need monitoring and renewal.
*   **Access Control** ensures proper permissions for Managed Identity.
*   **Runbook Logic**:
    *   Checks all secrets in Key Vault.
    *   Renews secrets expiring within 30 days.
    *   Sends email notifications summarizing updates.

***

### **Overview**

This script automates the renewal of secrets in Azure Key Vault and sends an email summary. It is designed to run as an **Azure Automation Runbook** using **Managed Identity** for secure authentication.

***

### **Steps Performed by the Script**

1.  **Import Modules**
    *   `Az.Accounts` and `Az.KeyVault` for Azure authentication and Key Vault operations.

2.  **Set Variables**
    *   Subscription ID, Tenant ID, Resource Group, Key Vault name, renewal threshold (30 days).

3.  **Email Settings**
    *   SMTP configuration for sending notifications via Office365.

4.  **Password Generator**
    *   Creates a strong random password for renewed secrets.

5.  **Authenticate**
    *   Uses Managed Identity to log in securely to Azure.

6.  **Fetch Secrets**
    *   Retrieves all secrets from the specified Key Vault.

7.  **Renewal Logic**
    *   If a secret expires within 30 days:
        *   Generate a new password.
        *   Update the secret with a new value and expiry date (+1 year).
        *   Log the update for reporting.

8.  **Email Notification**
    *   Builds an HTML email summarizing renewed secrets.
    *   Sends the email using SMTP (currently via `Send-MailMessage`).


