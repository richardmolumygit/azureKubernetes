In order to provision Azure resources using Terraform via a CI/CD pipeline from GitHub (GitHub Actions), you need an Azure Active Directory / Entra ID Service Principal, an Azure Storage Account for remote state management, and GitHub Secrets to secure your credentials.

The exact componets required are broken down into three foundational components:

1. **Authentication and Authorization (Identity)**
   Because GitHub runs your workflow externally, it needs authorization to make API calls to Azure. You must set up
   - **An Azure Service Principal (App Registration):**  This acts as the identity for your pipeline automation.
   _ **Role-Based Access Control (RBAC) Role Assignment:**  The Service Principal must be assigned a role such as **Contributor** or **Owner** scoped to your target Azure Subscription or Resource Group so Terraform has permission to create infrastructure
   - **Authentication Credentials:** You will need to capture four values from Azure:
     - ARM_CLIENT_ID (The Application/Client ID of the Service Principal)
       - Found under **Microsoft Entra ID** (For personal only there should only be one)
         - Under *Manage* > App registrations > gihb-actions-terraform > Application (client) ID
     - ARM_CLIENT_SECRET (A secret key generated for the Service Principal)
     - ARM_TENANT_ID (Your Azure Directory/Tenant ID)
     - ARM_SUBSCRIPTION_ID  (The ID of the Azure Subscription where resources will live)

*Note: While OpenID Connect (OIDC) federated credentials are often preferred for standard GitHub-to-Azure workflows to avoid secrets, Terraform automation natively relies on standard Client Secret / Service Principal environment variables.*

2. **Azure State Storage (The Backend)**
   Terraform tracks the state of your infrastructure in a .tfstate file. Since GitHub runners are ephemeral (destroyed after each run), you cannot store this locally. You need:
   - **Azure Storage Account & Blob Container:** This acts as the remote backend
   - **Permissions:** The Service Principal needs **Storage Blob Data Contributor** access to this container so the pipeline can read and write the state file during execution.

3. **GitHub Configuration**
   On the GitHub side, you must hook these components together:
   - **GitHub Encrypted Secrets:** You need to save your Azure credentials (ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID) as repository secrets so the workflow file can securely pass them to Terraform as environment variables
   - **Workflow YAML File:**  A workflow defined in your repository under .github/workflows/ that installs Terraform, logs into Azure, and runs the standard sequence (terraform init, terraform plan, and terraform apply).

4. **Build Agents and tooling (The Runtime)**
   - **Workflow YAML File:**  A workflow defined in your repository under .github/workflows/ that installs Terraform, logs into Azure, and runs the standard sequence (terraform init, terraform plan, and terraform apply).

5.  **Add Federated Credentials to the App registrations:** In order to authenticate using OIDC (OpenID Connect / Federated Credentials) it needs to be instructed to trust GitHub
    **Option 1:** via Azure Portal
    - Navigate to the **Microsoft Entra ID** (Azure Active Directory) blade.
    - Under *Manage*, select **App registrations**.
      In the *All appliations* click on your application **(github-actions-terraform)**.
    - Under *Manage*, click on **Certificates & secrets** in the left menu.
    - Switch to the **Federated credentials** tab and click **Add credential**.
    - Select **GitHub Actions deployed Azure resources** from the drop-down.
    - Fill in your GitHub details:
      1. **Organization/Owner:* Your GitHub username or organization name.
      2. **Repository:** Your repository name.
      3. **Entity type:** Select how your pipeline is triggered (usually Environment, Branch, or Pull request). For example, if your pipeline runs on the main branch, choose Branch and enter main
    - Give the credential a name and click **Add**.
    **Option 2:** Azure cli
    If you prefer the command line, you can create the federated credential by running the following command:
    bash
    ```
    az ad app federated-credential create \
    --id <AZURE_APP_OBJECT_ID> \
    --parameters '{
      "name": "github-actions-main-branch",
      "issuer": "https://githubusercontent.com",
      "subject": "repo:<GITHUB_ORG_OR_USER>/<REPO_NAME>:ref:refs/heads/main",
      "description": "Allow GitHub Actions to log in from the main branch",
      "audiences": ["api://AzureADTokenExchange"]
    }'
    ```

    **To find the <AZURE_APP_OBJECT_ID>**
    1. **Azure Portal**
       - Search for and select **Microsoft Entra ID** (formerly Azure Active Directory).
       - In the left-hand menu under the *Manage* section, click on **Enterprise applications.**
       - Search for your application by its name (the name of your GitHub CI/CD Service Principal).
       - Click on the application in the list. On the **Overview** blade, look for **Object ID** — this is your required target.
    2. **az cli**
       - **Option A:** If you already know the **Client ID (Application ID)** or the **Display Name** of your App Registration, you can quickly query the Object ID using [Azure CLI commands](https://learn.microsoft.com/en-us/cli/azure/?view=azure-cli-latest):
         bash
         ```
         az ad sp show --id <YOUR_CLIENT_ID> --query id --output tsv
         ```
       - **Option B:** If you only know the Display Name**
         bash
         ```
         az ad sp list --display-name "your-app-display-name" --query "[0].id" --output tsv
         ```

***

**Cost Braekdown**
  - **Microsoft Entra ID (Azure AD) Service Principal: Free.** Managing identity registration, creating Service Principals, and managing App Registrations are core directory features that do not incur any charges in the Microsoft Entra ID Free tier.
  - **Azure Storage Account (for Terraform/OpenTofu Remote State): Free (within limits).** The Azure Free Account includes 5 GB of LRS Blob Storage free for the first 12 months. Since a remote state file is typically only a few kilobytes or megabytes, it will comfortably remain 100% free.
  - *Option A: If you know the Client ID (Application ID)**
  - **GitHub Secrets: Free.** GitHub offers secrets management at no cost for all public repositories, as well as for private repositories under standard free accounts.

***

**Two Important Gotchas to Avoid Charges**

1. **Storage Redundancy:** When creating your Azure Storage Account, ensure you select **Locally Redundant Storage (LRS)**. Choosing Geo-Redundant Storage (GRS) will incur replication charges.

2. **Blob Operations:** While the storage space is free, Azure technically charges tiny fractions of a cent for read/write operations (e.g., $0.05 per 10,000 operations). Unless you are running CI/CD pipelines thousands of times a day, this will amount to $0.00.

## To find your client-id (Application ID) and tenant-id (Directory ID), you need to look at your App Registration inside the Microsoft Entra ID (formerly Azure Active Directory) portal.

Using the Azure Portal UI
1. Sign in to the Azure Portal.
2. Search for and select Microsoft Entra ID in the top search bar.
3. In the left-hand navigation menu, Under Manage, click on App registrations.
4. Click on the All applications
   - select the specific Service Principal/Application you created for your GitHub CI/CD pipeline.
   - - I created github-actions-terraform
5. You will see both IDs directly on the Overview page:
   - Application (client) ID -> This is your client-id.
   - Directory (tenant) ID -> This is your tenant-id.
