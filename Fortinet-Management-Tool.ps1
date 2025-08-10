<#
.SYNOPSIS
    A graphical tool for cloning and managing FortiGate Firewall Policies and Policy Routes.
.DESCRIPTION
    This script provides a GUI to connect to a FortiGate device via SSH.
    It allows for bulk cloning, enabling, and disabling of Firewall Policies and Policy Routes.
    Features advanced search by ID or Name/Address, and bulk actions like "Select All".
    All new objects are created in a 'disabled' state by default for safety.
.NOTES
    Author:  Hazem Mohamed & Enhanced by Google Gimini
    Version: 9.4 (Policy Route Fetch Fix)
    Developed by: Hazem Mohamed - Cybersecurity Engineer (hmohamed200@gmail.com)
    Requires: Posh-SSH module (Install-Module -Name Posh-SSH)
#>

# Check for Posh-SSH module and install if missing
if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Host "Posh-SSH module not found. Attempting to install..."
    try {
        Install-Module -Name Posh-SSH -Force -Scope CurrentUser -ErrorAction Stop
        Write-Host "Posh-SSH installed successfully. Please restart the script."
    }
    catch {
        Write-Error "Failed to install Posh-SSH. Please install it manually: Install-Module -Name Posh-SSH"
    }
    return
}

# Force import the module to ensure it's loaded
try {
    Import-Module -Name Posh-SSH -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to load Posh-SSH module. Please ensure it is installed correctly and run PowerShell as Administrator."
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Failed to load Posh-SSH module. The script cannot run.", "Fatal Error", "OK", "Error")
    return
}

# Add Windows Forms assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =================================================================================
# Script Functions (Defined at the top to prevent errors)
# =================================================================================

# Function to add a message to the log
function Add-Log {
    param ($message)
    if ($logTextBox) {
        $logTextBox.AppendText("$(Get-Date -Format 'HH:mm:ss') - $message`r`n")
    }
}

# Function to load an image from a URL into a PictureBox
function Load-ImageFromUrl {
    param(
        [System.Windows.Forms.PictureBox]$PictureBox,
        [string]$Url
    )
    try {
        # *** CHANGE: Enforce TLS 1.2 for compatibility with older systems ***
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $imageData = $webClient.DownloadData($Url)
        $memoryStream = New-Object System.IO.MemoryStream($imageData)
        $PictureBox.Image = [System.Drawing.Image]::FromStream($memoryStream)
    }
    catch {
        Add-Log "Failed to load logo from URL: $Url"
    }
}

# Function to show the interface selection dialog for Firewall Policies
function Show-FwInterfaceDialog {
    param(
        [string]$Title,
        [array]$interfaces
    )

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $Title
    $dialog.Size = New-Object System.Drawing.Size(400, 200)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = 'FixedDialog'

    $srcLabel = New-Object System.Windows.Forms.Label
    $srcLabel.Text = "Source Interface (srcintf):"
    $srcLabel.Location = New-Object System.Drawing.Point(20, 20)
    $srcLabel.Size = New-Object System.Drawing.Size(150, 20)
    $dialog.Controls.Add($srcLabel)

    $srcComboBox = New-Object System.Windows.Forms.ComboBox
    $srcComboBox.Location = New-Object System.Drawing.Point(180, 20)
    $srcComboBox.Size = New-Object System.Drawing.Size(180, 20)
    $srcComboBox.Items.AddRange($interfaces)
    $dialog.Controls.Add($srcComboBox)

    $dstLabel = New-Object System.Windows.Forms.Label
    $dstLabel.Text = "Destination Interface (dstintf):"
    $dstLabel.Location = New-Object System.Drawing.Point(20, 60)
    $dstLabel.Size = New-Object System.Drawing.Size(150, 20)
    $dialog.Controls.Add($dstLabel)

    $dstComboBox = New-Object System.Windows.Forms.ComboBox
    $dstComboBox.Location = New-Object System.Drawing.Point(180, 60)
    $dstComboBox.Size = New-Object System.Drawing.Size(180, 20)
    $dstComboBox.Items.AddRange($interfaces)
    $dialog.Controls.Add($dstComboBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(100, 120)
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dialog.AcceptButton = $okButton
    $dialog.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Location = New-Object System.Drawing.Point(200, 120)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dialog.CancelButton = $cancelButton
    $dialog.Controls.Add($cancelButton)
    
    $dialog.TopMost = $true
    $result = $dialog.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        if ([string]::IsNullOrWhiteSpace($srcComboBox.Text) -or [string]::IsNullOrWhiteSpace($dstComboBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Source and Destination interfaces must be selected.", "Error", "OK", "Error")
            return $null
        }
        return @{
            Source = $srcComboBox.Text
            Destination = $dstComboBox.Text
        }
    }
    return $null
}

# Function to show the interface selection dialog for Policy Routes
function Show-RouteInterfacesDialog {
    param(
        [string]$Title,
        [array]$interfaces
    )

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $Title
    $dialog.Size = New-Object System.Drawing.Size(400, 200)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = 'FixedDialog'

    $inLabel = New-Object System.Windows.Forms.Label
    $inLabel.Text = "Input Device:"
    $inLabel.Location = New-Object System.Drawing.Point(10, 20)
    $inLabel.Size = New-Object System.Drawing.Size(160, 20)
    $dialog.Controls.Add($inLabel)

    $inComboBox = New-Object System.Windows.Forms.ComboBox
    $inComboBox.Location = New-Object System.Drawing.Point(180, 20)
    $inComboBox.Size = New-Object System.Drawing.Size(180, 20)
    $inComboBox.Items.AddRange($interfaces)
    $dialog.Controls.Add($inComboBox)

    $outLabel = New-Object System.Windows.Forms.Label
    $outLabel.Text = "Output Device:"
    $outLabel.Location = New-Object System.Drawing.Point(10, 60)
    $outLabel.Size = New-Object System.Drawing.Size(160, 20)
    $dialog.Controls.Add($outLabel)

    $outComboBox = New-Object System.Windows.Forms.ComboBox
    $outComboBox.Location = New-Object System.Drawing.Point(180, 60)
    $outComboBox.Size = New-Object System.Drawing.Size(180, 20)
    $outComboBox.Items.AddRange($interfaces)
    $dialog.Controls.Add($outComboBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(100, 120)
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dialog.AcceptButton = $okButton
    $dialog.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Location = New-Object System.Drawing.Point(200, 120)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dialog.CancelButton = $cancelButton
    $dialog.Controls.Add($cancelButton)
    
    $dialog.TopMost = $true
    $result = $dialog.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        if ([string]::IsNullOrWhiteSpace($inComboBox.Text) -or [string]::IsNullOrWhiteSpace($outComboBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Input and Output devices must be selected.", "Error", "OK", "Error")
            return $null
        }
        return @{
            Input = $inComboBox.Text
            Output = $outComboBox.Text
        }
    }
    return $null
}

# Function to build the command prefix for VDOMs
function Get-CommandPrefix {
    param($vdomName)
    if (-not [string]::IsNullOrWhiteSpace($vdomName)) {
        return "config vdom`nedit `"$vdomName`"`n"
    }
    return ""
}

# =================================================================================
# Main Form Definition
# =================================================================================
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Advanced FortiGate Tool | ® Developed by Hazem Mohamed"
$mainForm.Size = New-Object System.Drawing.Size(840, 900) 
$mainForm.MinimumSize = New-Object System.Drawing.Size(840, 600)
$mainForm.StartPosition = "CenterScreen"
$mainForm.FormBorderStyle = 'Sizable' 
$mainForm.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Dock = 'Fill'
$mainPanel.AutoScroll = $true
$mainForm.Controls.Add($mainPanel)

# Global variables to store fetched items
$script:allFirewallPolicies = [System.Collections.Generic.List[string]]::new()
$script:allPolicyRoutes = [System.Collections.Generic.List[string]]::new()

# =================================================================================
# UI Element Definitions
# =================================================================================

# --- Connection Group ---
$connectionGroup = New-Object System.Windows.Forms.GroupBox
$connectionGroup.Text = "Connection Information"
$connectionGroup.Location = New-Object System.Drawing.Point(10, 10)
$connectionGroup.Size = New-Object System.Drawing.Size(790, 140)
$connectionGroup.Anchor = 'Top, Left, Right'
$mainPanel.Controls.Add($connectionGroup)

$fortinetLogoBox = New-Object System.Windows.Forms.PictureBox
$fortinetLogoBox.Location = New-Object System.Drawing.Point(10, 20)
$fortinetLogoBox.Size = New-Object System.Drawing.Size(120, 30)
$fortinetLogoBox.SizeMode = 'Zoom'
$connectionGroup.Controls.Add($fortinetLogoBox)

$freeMindLogoBox = New-Object System.Windows.Forms.PictureBox
$freeMindLogoBox.Location = New-Object System.Drawing.Point(650, 20)
$freeMindLogoBox.Size = New-Object System.Drawing.Size(130, 30)
$freeMindLogoBox.SizeMode = 'Zoom'
$freeMindLogoBox.Anchor = 'Top, Right'
$connectionGroup.Controls.Add($freeMindLogoBox)

$ipLabel = New-Object System.Windows.Forms.Label
$ipLabel.Text = "IP Address:"
$ipLabel.Location = New-Object System.Drawing.Point(10, 60)
$connectionGroup.Controls.Add($ipLabel)

$ipTextBox = New-Object System.Windows.Forms.TextBox
$ipTextBox.Location = New-Object System.Drawing.Point(120, 57)
$ipTextBox.Size = New-Object System.Drawing.Size(150, 20)
$connectionGroup.Controls.Add($ipTextBox)

$userLabel = New-Object System.Windows.Forms.Label
$userLabel.Text = "Username:"
$userLabel.Location = New-Object System.Drawing.Point(10, 90)
$connectionGroup.Controls.Add($userLabel)

$userTextBox = New-Object System.Windows.Forms.TextBox
$userTextBox.Location = New-Object System.Drawing.Point(120, 87)
$userTextBox.Size = New-Object System.Drawing.Size(150, 20)
$connectionGroup.Controls.Add($userTextBox)

$passLabel = New-Object System.Windows.Forms.Label
$passLabel.Text = "Password:"
$passLabel.Location = New-Object System.Drawing.Point(280, 60)
$connectionGroup.Controls.Add($passLabel)

$passTextBox = New-Object System.Windows.Forms.TextBox
$passTextBox.Location = New-Object System.Drawing.Point(380, 57)
$passTextBox.Size = New-Object System.Drawing.Size(150, 20)
$passTextBox.PasswordChar = '*'
$connectionGroup.Controls.Add($passTextBox)

$vdomLabel = New-Object System.Windows.Forms.Label
$vdomLabel.Text = "VDOM (Optional):"
$vdomLabel.Location = New-Object System.Drawing.Point(280, 90)
$connectionGroup.Controls.Add($vdomLabel)

$vdomTextBox = New-Object System.Windows.Forms.TextBox
$vdomTextBox.Location = New-Object System.Drawing.Point(380, 87)
$vdomTextBox.Size = New-Object System.Drawing.Size(150, 20)
$connectionGroup.Controls.Add($vdomTextBox)

$connectButton = New-Object System.Windows.Forms.Button
$connectButton.Text = "Connect"
$connectButton.Location = New-Object System.Drawing.Point(550, 70)
$connectButton.Size = New-Object System.Drawing.Size(100, 30)
$connectionGroup.Controls.Add($connectButton)

$logoutButton = New-Object System.Windows.Forms.Button
$logoutButton.Text = "Disconnect"
$logoutButton.Location = New-Object System.Drawing.Point(660, 70)
$logoutButton.Size = New-Object System.Drawing.Size(110, 30)
$logoutButton.Enabled = $false
$connectionGroup.Controls.Add($logoutButton)

# --- Firewall Policies Cloning Group ---
$fwPoliciesGroup = New-Object System.Windows.Forms.GroupBox
$fwPoliciesGroup.Text = "Firewall Policies - Cloning"
$fwPoliciesGroup.Location = New-Object System.Drawing.Point(10, 160)
$fwPoliciesGroup.Size = New-Object System.Drawing.Size(790, 180)
$fwPoliciesGroup.Enabled = $false
$fwPoliciesGroup.Anchor = 'Top, Left, Right'
$mainPanel.Controls.Add($fwPoliciesGroup)

$fetchFwPoliciesButton = New-Object System.Windows.Forms.Button
$fetchFwPoliciesButton.Text = "Fetch Policies"
$fetchFwPoliciesButton.Location = New-Object System.Drawing.Point(10, 25)
$fetchFwPoliciesButton.Size = New-Object System.Drawing.Size(120, 30)
$fwPoliciesGroup.Controls.Add($fetchFwPoliciesButton)

$searchFwCloningLabel = New-Object System.Windows.Forms.Label
$searchFwCloningLabel.Text = "Search by:"
$searchFwCloningLabel.Location = New-Object System.Drawing.Point(150, 32)
$fwPoliciesGroup.Controls.Add($searchFwCloningLabel)

$searchFwCloningComboBox = New-Object System.Windows.Forms.ComboBox
$searchFwCloningComboBox.Location = New-Object System.Drawing.Point(220, 29)
$searchFwCloningComboBox.Size = New-Object System.Drawing.Size(80, 20)
$searchFwCloningComboBox.Items.AddRange(@("ID", "Name"))
$searchFwCloningComboBox.SelectedIndex = 0
$fwPoliciesGroup.Controls.Add($searchFwCloningComboBox)

$searchFwCloningTextBox = New-Object System.Windows.Forms.TextBox
$searchFwCloningTextBox.Location = New-Object System.Drawing.Point(310, 29)
$searchFwCloningTextBox.Size = New-Object System.Drawing.Size(150, 20)
$searchFwCloningTextBox.Anchor = 'Top, Left, Right'
$fwPoliciesGroup.Controls.Add($searchFwCloningTextBox)

$searchFwCloningButton = New-Object System.Windows.Forms.Button
$searchFwCloningButton.Text = "Search"
$searchFwCloningButton.Location = New-Object System.Drawing.Point(470, 25)
$searchFwCloningButton.Anchor = 'Top, Right'
$searchFwCloningButton.Size = New-Object System.Drawing.Size(80, 30)
$fwPoliciesGroup.Controls.Add($searchFwCloningButton)

$clearFwCloningSearchButton = New-Object System.Windows.Forms.Button
$clearFwCloningSearchButton.Text = "Show All"
$clearFwCloningSearchButton.Location = New-Object System.Drawing.Point(560, 25)
$clearFwCloningSearchButton.Anchor = 'Top, Right'
$clearFwCloningSearchButton.Size = New-Object System.Drawing.Size(80, 30)
$fwPoliciesGroup.Controls.Add($clearFwCloningSearchButton)

$copyFwButton = New-Object System.Windows.Forms.Button
$copyFwButton.Text = "Clone Selected"
$copyFwButton.Location = New-Object System.Drawing.Point(650, 25)
$copyFwButton.Anchor = 'Top, Right'
$copyFwButton.Size = New-Object System.Drawing.Size(120, 30)
$fwPoliciesGroup.Controls.Add($copyFwButton)

$fwPoliciesCheckedListBox = New-Object System.Windows.Forms.CheckedListBox
$fwPoliciesCheckedListBox.Location = New-Object System.Drawing.Point(10, 65)
$fwPoliciesCheckedListBox.Size = New-Object System.Drawing.Size(770, 100)
$fwPoliciesCheckedListBox.Anchor = 'Top, Bottom, Left, Right'
$fwPoliciesGroup.Controls.Add($fwPoliciesCheckedListBox)

# --- Policy Status Management Group ---
$statusMgmtGroup = New-Object System.Windows.Forms.GroupBox
$statusMgmtGroup.Text = "Policy Status Management"
$statusMgmtGroup.Location = New-Object System.Drawing.Point(10, 350)
$statusMgmtGroup.Size = New-Object System.Drawing.Size(790, 220)
$statusMgmtGroup.Enabled = $false
$statusMgmtGroup.Anchor = 'Top, Left, Right'
$mainPanel.Controls.Add($statusMgmtGroup)

$searchMgmtLabel = New-Object System.Windows.Forms.Label
$searchMgmtLabel.Text = "Search by:"
$searchMgmtLabel.Location = New-Object System.Drawing.Point(10, 32)
$statusMgmtGroup.Controls.Add($searchMgmtLabel)

$searchMgmtComboBox = New-Object System.Windows.Forms.ComboBox
$searchMgmtComboBox.Location = New-Object System.Drawing.Point(80, 29)
$searchMgmtComboBox.Size = New-Object System.Drawing.Size(80, 20)
$searchMgmtComboBox.Items.AddRange(@("ID", "Name"))
$searchMgmtComboBox.SelectedIndex = 0
$statusMgmtGroup.Controls.Add($searchMgmtComboBox)

$searchMgmtTextBox = New-Object System.Windows.Forms.TextBox
$searchMgmtTextBox.Location = New-Object System.Drawing.Point(170, 29)
$searchMgmtTextBox.Size = New-Object System.Drawing.Size(200, 20)
$searchMgmtTextBox.Anchor = 'Top, Left, Right'
$statusMgmtGroup.Controls.Add($searchMgmtTextBox)

$searchMgmtButton = New-Object System.Windows.Forms.Button
$searchMgmtButton.Text = "Search"
$searchMgmtButton.Location = New-Object System.Drawing.Point(380, 25)
$searchMgmtButton.Anchor = 'Top, Right'
$searchMgmtButton.Size = New-Object System.Drawing.Size(90, 30)
$statusMgmtGroup.Controls.Add($searchMgmtButton)

$selectAllMgmtButton = New-Object System.Windows.Forms.Button
$selectAllMgmtButton.Text = "Select All"
$selectAllMgmtButton.Location = New-Object System.Drawing.Point(475, 25)
$selectAllMgmtButton.Anchor = 'Top, Right'
$selectAllMgmtButton.Size = New-Object System.Drawing.Size(90, 30)
$statusMgmtGroup.Controls.Add($selectAllMgmtButton)

$deselectAllMgmtButton = New-Object System.Windows.Forms.Button
$deselectAllMgmtButton.Text = "Deselect All"
$deselectAllMgmtButton.Location = New-Object System.Drawing.Point(570, 25)
$deselectAllMgmtButton.Anchor = 'Top, Right'
$deselectAllMgmtButton.Size = New-Object System.Drawing.Size(90, 30)
$statusMgmtGroup.Controls.Add($deselectAllMgmtButton)

$enableSelectedButton = New-Object System.Windows.Forms.Button
$enableSelectedButton.Text = "Enable"
$enableSelectedButton.Location = New-Object System.Drawing.Point(665, 25)
$enableSelectedButton.Anchor = 'Top, Right'
$enableSelectedButton.Size = New-Object System.Drawing.Size(55, 30)
$enableSelectedButton.BackColor = [System.Drawing.Color]::LightGreen
$statusMgmtGroup.Controls.Add($enableSelectedButton)

$disableSelectedButton = New-Object System.Windows.Forms.Button
$disableSelectedButton.Text = "Disable"
$disableSelectedButton.Location = New-Object System.Drawing.Point(725, 25)
$disableSelectedButton.Anchor = 'Top, Right'
$disableSelectedButton.Size = New-Object System.Drawing.Size(55, 30)
$disableSelectedButton.BackColor = [System.Drawing.Color]::LightCoral
$statusMgmtGroup.Controls.Add($disableSelectedButton)

$statusMgmtCheckedListBox = New-Object System.Windows.Forms.CheckedListBox
$statusMgmtCheckedListBox.Location = New-Object System.Drawing.Point(10, 65)
$statusMgmtCheckedListBox.Size = New-Object System.Drawing.Size(770, 140)
$statusMgmtCheckedListBox.Anchor = 'Top, Bottom, Left, Right'
$statusMgmtGroup.Controls.Add($statusMgmtCheckedListBox)

# --- Policy Routes Cloning Group ---
$routePoliciesGroup = New-Object System.Windows.Forms.GroupBox
$routePoliciesGroup.Text = "Policy Routes - Cloning"
$routePoliciesGroup.Location = New-Object System.Drawing.Point(10, 580)
$routePoliciesGroup.Size = New-Object System.Drawing.Size(790, 180)
$routePoliciesGroup.Enabled = $false
$routePoliciesGroup.Anchor = 'Top, Left, Right'
$mainPanel.Controls.Add($routePoliciesGroup)

$fetchRoutesButton = New-Object System.Windows.Forms.Button
$fetchRoutesButton.Text = "Fetch Routes"
$fetchRoutesButton.Location = New-Object System.Drawing.Point(10, 25)
$fetchRoutesButton.Size = New-Object System.Drawing.Size(120, 30)
$routePoliciesGroup.Controls.Add($fetchRoutesButton)

$searchRouteCloningLabel = New-Object System.Windows.Forms.Label
$searchRouteCloningLabel.Text = "Search by:"
$searchRouteCloningLabel.Location = New-Object System.Drawing.Point(150, 32)
$routePoliciesGroup.Controls.Add($searchRouteCloningLabel)

$searchRouteCloningComboBox = New-Object System.Windows.Forms.ComboBox
$searchRouteCloningComboBox.Location = New-Object System.Drawing.Point(220, 29)
$searchRouteCloningComboBox.Size = New-Object System.Drawing.Size(80, 20)
$searchRouteCloningComboBox.Items.AddRange(@("ID", "Src", "Dst"))
$searchRouteCloningComboBox.SelectedIndex = 0
$routePoliciesGroup.Controls.Add($searchRouteCloningComboBox)

$searchRouteCloningTextBox = New-Object System.Windows.Forms.TextBox
$searchRouteCloningTextBox.Location = New-Object System.Drawing.Point(310, 29)
$searchRouteCloningTextBox.Size = New-Object System.Drawing.Size(150, 20)
$searchRouteCloningTextBox.Anchor = 'Top, Left, Right'
$routePoliciesGroup.Controls.Add($searchRouteCloningTextBox)

$searchRouteCloningButton = New-Object System.Windows.Forms.Button
$searchRouteCloningButton.Text = "Search"
$searchRouteCloningButton.Location = New-Object System.Drawing.Point(470, 25)
$searchRouteCloningButton.Anchor = 'Top, Right'
$searchRouteCloningButton.Size = New-Object System.Drawing.Size(80, 30)
$routePoliciesGroup.Controls.Add($searchRouteCloningButton)

$clearRouteCloningSearchButton = New-Object System.Windows.Forms.Button
$clearRouteCloningSearchButton.Text = "Show All"
$clearRouteCloningSearchButton.Location = New-Object System.Drawing.Point(560, 25)
$clearRouteCloningSearchButton.Anchor = 'Top, Right'
$clearRouteCloningSearchButton.Size = New-Object System.Drawing.Size(80, 30)
$routePoliciesGroup.Controls.Add($clearRouteCloningSearchButton)

$copyRoutesButton = New-Object System.Windows.Forms.Button
$copyRoutesButton.Text = "Clone Selected"
$copyRoutesButton.Location = New-Object System.Drawing.Point(650, 25)
$copyRoutesButton.Anchor = 'Top, Right'
$copyRoutesButton.Size = New-Object System.Drawing.Size(120, 30)
$routePoliciesGroup.Controls.Add($copyRoutesButton)

$routePoliciesCheckedListBox = New-Object System.Windows.Forms.CheckedListBox
$routePoliciesCheckedListBox.Location = New-Object System.Drawing.Point(10, 65)
$routePoliciesCheckedListBox.Size = New-Object System.Drawing.Size(770, 100)
$routePoliciesCheckedListBox.Anchor = 'Top, Bottom, Left, Right'
$routePoliciesGroup.Controls.Add($routePoliciesCheckedListBox)

# --- Policy Route Status Management Group ---
$routeStatusMgmtGroup = New-Object System.Windows.Forms.GroupBox
$routeStatusMgmtGroup.Text = "Policy Route Status Management"
$routeStatusMgmtGroup.Location = New-Object System.Drawing.Point(10, 770)
$routeStatusMgmtGroup.Size = New-Object System.Drawing.Size(790, 220)
$routeStatusMgmtGroup.Enabled = $false
$routeStatusMgmtGroup.Anchor = 'Top, Left, Right'
$mainPanel.Controls.Add($routeStatusMgmtGroup)

$searchRouteMgmtLabel = New-Object System.Windows.Forms.Label
$searchRouteMgmtLabel.Text = "Search by:"
$searchRouteMgmtLabel.Location = New-Object System.Drawing.Point(10, 32)
$routeStatusMgmtGroup.Controls.Add($searchRouteMgmtLabel)

$searchRouteMgmtComboBox = New-Object System.Windows.Forms.ComboBox
$searchRouteMgmtComboBox.Location = New-Object System.Drawing.Point(80, 29)
$searchRouteMgmtComboBox.Size = New-Object System.Drawing.Size(80, 20)
$searchRouteMgmtComboBox.Items.AddRange(@("ID", "Src", "Dst"))
$searchRouteMgmtComboBox.SelectedIndex = 0
$routeStatusMgmtGroup.Controls.Add($searchRouteMgmtComboBox)

$searchRouteMgmtTextBox = New-Object System.Windows.Forms.TextBox
$searchRouteMgmtTextBox.Location = New-Object System.Drawing.Point(170, 29)
$searchRouteMgmtTextBox.Size = New-Object System.Drawing.Size(200, 20)
$searchRouteMgmtTextBox.Anchor = 'Top, Left, Right'
$routeStatusMgmtGroup.Controls.Add($searchRouteMgmtTextBox)

$searchRouteMgmtButton = New-Object System.Windows.Forms.Button
$searchRouteMgmtButton.Text = "Search"
$searchRouteMgmtButton.Location = New-Object System.Drawing.Point(380, 25)
$searchRouteMgmtButton.Anchor = 'Top, Right'
$searchRouteMgmtButton.Size = New-Object System.Drawing.Size(90, 30)
$routeStatusMgmtGroup.Controls.Add($searchRouteMgmtButton)

$selectAllRouteMgmtButton = New-Object System.Windows.Forms.Button
$selectAllRouteMgmtButton.Text = "Select All"
$selectAllRouteMgmtButton.Location = New-Object System.Drawing.Point(475, 25)
$selectAllRouteMgmtButton.Anchor = 'Top, Right'
$selectAllRouteMgmtButton.Size = New-Object System.Drawing.Size(90, 30)
$routeStatusMgmtGroup.Controls.Add($selectAllRouteMgmtButton)

$deselectAllRouteMgmtButton = New-Object System.Windows.Forms.Button
$deselectAllRouteMgmtButton.Text = "Deselect All"
$deselectAllRouteMgmtButton.Location = New-Object System.Drawing.Point(570, 25)
$deselectAllRouteMgmtButton.Anchor = 'Top, Right'
$deselectAllRouteMgmtButton.Size = New-Object System.Drawing.Size(90, 30)
$routeStatusMgmtGroup.Controls.Add($deselectAllRouteMgmtButton)

$enableSelectedRoutesButton = New-Object System.Windows.Forms.Button
$enableSelectedRoutesButton.Text = "Enable"
$enableSelectedRoutesButton.Location = New-Object System.Drawing.Point(665, 25)
$enableSelectedRoutesButton.Anchor = 'Top, Right'
$enableSelectedRoutesButton.Size = New-Object System.Drawing.Size(55, 30)
$enableSelectedRoutesButton.BackColor = [System.Drawing.Color]::LightGreen
$routeStatusMgmtGroup.Controls.Add($enableSelectedRoutesButton)

$disableSelectedRoutesButton = New-Object System.Windows.Forms.Button
$disableSelectedRoutesButton.Text = "Disable"
$disableSelectedRoutesButton.Location = New-Object System.Drawing.Point(725, 25)
$disableSelectedRoutesButton.Anchor = 'Top, Right'
$disableSelectedRoutesButton.Size = New-Object System.Drawing.Size(55, 30)
$disableSelectedRoutesButton.BackColor = [System.Drawing.Color]::LightCoral
$routeStatusMgmtGroup.Controls.Add($disableSelectedRoutesButton)

$routeStatusMgmtCheckedListBox = New-Object System.Windows.Forms.CheckedListBox
$routeStatusMgmtCheckedListBox.Location = New-Object System.Drawing.Point(10, 65)
$routeStatusMgmtCheckedListBox.Size = New-Object System.Drawing.Size(770, 140)
$routeStatusMgmtCheckedListBox.Anchor = 'Top, Bottom, Left, Right'
$routeStatusMgmtGroup.Controls.Add($routeStatusMgmtCheckedListBox)


# --- Log Group ---
$logGroup = New-Object System.Windows.Forms.GroupBox
$logGroup.Text = "Log"
$logGroup.Location = New-Object System.Drawing.Point(10, 1000)
$logGroup.Size = New-Object System.Drawing.Size(790, 100)
$logGroup.Anchor = 'Top, Left, Right'
$mainPanel.Controls.Add($logGroup)

$logTextBox = New-Object System.Windows.Forms.TextBox
$logTextBox.Location = New-Object System.Drawing.Point(10, 25)
$logTextBox.Size = New-Object System.Drawing.Size(770, 65) 
$logTextBox.Multiline = $true
$logTextBox.ScrollBars = "Vertical"
$logTextBox.ReadOnly = $true
$logTextBox.Anchor = 'Top, Bottom, Left, Right'
$logGroup.Controls.Add($logTextBox)

# --- Attribution Group ---
$attributionLabel = New-Object System.Windows.Forms.Label
$attributionLabel.Text = "® Developed by Hazem Mohamed - Cybersecurity Engineer | Contact: hmohamed200@gmail.com"
$attributionLabel.Location = New-Object System.Drawing.Point(10, 1110) 
$attributionLabel.Size = New-Object System.Drawing.Size(790, 20)
$attributionLabel.TextAlign = "MiddleCenter"
$attributionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8) 
$mainPanel.Controls.Add($attributionLabel)


# =================================================================================
# Button Event Handlers
# =================================================================================

# Connect Button Click Event
$connectButton.Add_Click({
    $ip = $ipTextBox.Text
    $user = $userTextBox.Text
    $pass = $passTextBox.Text

    if ([string]::IsNullOrWhiteSpace($ip) -or [string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($pass)) {
        Add-Log "Error: Please fill in all connection fields."
        return
    }

    $credential = New-Object System.Management.Automation.PSCredential($user, ($pass | ConvertTo-SecureString -AsPlainText -Force))
    
    try {
        Add-Log "Connecting to $ip..."
        $script:sshSession = New-SSHSession -ComputerName $ip -Credential $credential -ConnectionTimeout 20 -ErrorAction Stop
        
        if ($sshSession.Connected) {
            Add-Log "Connection successful."
            $fwPoliciesGroup.Enabled = $true
            $routePoliciesGroup.Enabled = $true
            $statusMgmtGroup.Enabled = $true
            $routeStatusMgmtGroup.Enabled = $true
            $connectButton.Enabled = $false
            $logoutButton.Enabled = $true
            $ipTextBox.Enabled = $false
            $userTextBox.Enabled = $false
            $passTextBox.Enabled = $false
            $vdomTextBox.Enabled = $false
        } else {
            Add-Log "Connection failed. Check credentials or SSH settings on the FortiGate."
        }
    }
    catch {
        Add-Log "An error occurred during connection: $($_.Exception.Message)"
    }
})

# Disconnect Button Click Event
$logoutButton.Add_Click({
    if ($script:sshSession -and $script:sshSession.Connected) {
        Add-Log "Disconnecting..."
        Remove-SSHSession -SSHSession $script:sshSession
        $script:sshSession = $null
        Add-Log "Successfully disconnected."
    }
    
    # Reset UI
    $fwPoliciesGroup.Enabled = $false
    $routePoliciesGroup.Enabled = $false
    $statusMgmtGroup.Enabled = $false
    $routeStatusMgmtGroup.Enabled = $false
    
    $fwPoliciesCheckedListBox.Items.Clear()
    $routePoliciesCheckedListBox.Items.Clear()
    $statusMgmtCheckedListBox.Items.Clear()
    $routeStatusMgmtCheckedListBox.Items.Clear()
    $script:allFirewallPolicies.Clear()
    $script:allPolicyRoutes.Clear()
    $searchMgmtTextBox.Text = ""
    $searchFwCloningTextBox.Text = ""
    $searchRouteCloningTextBox.Text = ""
    $searchRouteMgmtTextBox.Text = ""

    $connectButton.Enabled = $true
    $logoutButton.Enabled = $false
    $ipTextBox.Enabled = $true
    $userTextBox.Enabled = $true
    $passTextBox.Enabled = $true
    $vdomTextBox.Enabled = $true
})


# Fetch Firewall Policies Button Click Event
$fetchFwPoliciesButton.Add_Click({
    Add-Log "Fetching firewall policies..."
    $fwPoliciesCheckedListBox.Items.Clear()
    $statusMgmtCheckedListBox.Items.Clear() # Also clear the management list
    $script:allFirewallPolicies.Clear()
    
    try {
        $vdomName = $vdomTextBox.Text
        $commandPrefix = Get-CommandPrefix -vdomName $vdomName
        
        $command = "${commandPrefix}config system console`nset output standard`nend`nshow firewall policy"
        $output = Invoke-SSHCommand -SSHSession $script:sshSession -Command $command
        
        $policies = ($output.Output -join "`n") -split '(?=edit \d+)'
        
        foreach ($policy in $policies) {
            if ($policy -match 'edit (\d+)') {
                $policyId = $matches[1]
                $policyName = ""
                if ($policy -match 'set name "([^"]+)"') {
                    $policyName = $matches[1]
                }
                $displayText = "ID: $policyId"
                if (-not [string]::IsNullOrWhiteSpace($policyName)) {
                    $displayText += " - Name: $policyName"
                }
                $script:allFirewallPolicies.Add($displayText)
            }
        }
        $fwPoliciesCheckedListBox.Items.AddRange($script:allFirewallPolicies)
        $statusMgmtCheckedListBox.Items.AddRange($script:allFirewallPolicies) # Populate management list
        Add-Log "Fetched $($script:allFirewallPolicies.Count) policies."
    }
    catch {
        Add-Log "An error occurred while fetching policies: $($_.Exception.Message)"
    }
})

# Clone Firewall Policies Button Click Event
$copyFwButton.Add_Click({
    $selectedPolicies = $fwPoliciesCheckedListBox.CheckedItems
    if ($selectedPolicies.Count -eq 0) {
        Add-Log "No firewall policies selected for cloning."
        return
    }

    $vdomName = $vdomTextBox.Text
    $commandPrefix = Get-CommandPrefix -vdomName $vdomName

    # Fetch available interfaces once
    Add-Log "Fetching available interfaces..."
    try {
        $interfacesCommand = "${commandPrefix}config system console`nset output standard`nend`nshow system interface"
        $interfacesOutput = Invoke-SSHCommand -SSHSession $script:sshSession -Command $interfacesCommand
        
        $interfaces = [System.Collections.Generic.List[string]]::new()
        $fullOutput = $interfacesOutput.Output -join "`n"
        $interfaceBlocks = $fullOutput -split '(?=edit "*)'
        foreach ($block in $interfaceBlocks) {
            if ($block -match 'edit "([^"]+)"') {
                $interfaces.Add($matches[1])
            }
        }
    }
    catch {
        Add-Log "Failed to fetch interfaces. Cannot proceed."
        return
    }
    
    if ($interfaces.Count -eq 0) {
        Add-Log "Error: No interfaces found. Check device configuration."
        return
    }

    Add-Log "Found $($interfaces.Count) interfaces."

    $dialogTitle = "Select new interfaces for all selected policies"
    $newInterfaces = Show-FwInterfaceDialog -Title $dialogTitle -interfaces $interfaces
        
    if ($null -eq $newInterfaces) {
        Add-Log "Cloning process cancelled."
        return
    }

    $newSrcIntf = $newInterfaces.Source
    $newDstIntf = $newInterfaces.Destination
    Add-Log "Applying new interfaces to all policies: Source='$newSrcIntf', Destination='$newDstIntf'"


    foreach ($selectedPolicy in $selectedPolicies) {
        $policyId = ($selectedPolicy -split ' ')[1]
        Add-Log "Preparing to clone policy ID $policyId..."

        # Fetch original policy config
        $policyConfigCommand = "${commandPrefix}config system console`nset output standard`nend`nshow firewall policy $policyId"
        $policyConfigOutput = Invoke-SSHCommand -SSHSession $script:sshSession -Command $policyConfigCommand
        $policyConfigLines = $policyConfigOutput.Output

        # Build new policy commands
        $newPolicyCommands = New-Object System.Text.StringBuilder
        if (-not [string]::IsNullOrWhiteSpace($vdomName)) {
            $newPolicyCommands.AppendLine("config vdom") | Out-Null
            $newPolicyCommands.AppendLine("edit `"$vdomName`"") | Out-Null
        }
        $newPolicyCommands.AppendLine("config firewall policy") | Out-Null
        $newPolicyCommands.AppendLine("edit 0") | Out-Null

        foreach ($line in $policyConfigLines) {
            $trimmedLine = $line.Trim()

            if (-not ($trimmedLine -match '^set\s+\S+')) { continue }

            if ($trimmedLine.StartsWith("set srcintf")) {
                $newPolicyCommands.AppendLine("set srcintf `"$newSrcIntf`"") | Out-Null
            }
            elseif ($trimmedLine.StartsWith("set dstintf")) {
                $newPolicyCommands.AppendLine("set dstintf `"$newDstIntf`"") | Out-Null
            }
            elseif ($trimmedLine.StartsWith("set name")) {
                $originalName = ($trimmedLine -split '"')[1]
                
                $prefix = "Copy_of_"
                $maxLength = 35
                $maxOriginalNameLength = $maxLength - $prefix.Length
                if ($originalName.Length -gt $maxOriginalNameLength) {
                    $truncatedName = $originalName.Substring(0, $maxOriginalNameLength)
                    $newName = "$prefix$truncatedName"
                    Add-Log "  - Original policy name was too long, truncated."
                } else {
                    $newName = "$prefix$originalName"
                }
                $newPolicyCommands.AppendLine("set name `"$newName`"") | Out-Null
            }
            elseif ($trimmedLine.StartsWith("set uuid")) { # Ignore
            }
            else {
                # Copy all other 'set' commands as is
                $newPolicyCommands.AppendLine($trimmedLine) | Out-Null
            }
        }
        
        $newPolicyCommands.AppendLine("set status disable") | Out-Null
        $newPolicyCommands.AppendLine("set comments `"Copied from policy $policyId via PowerShell script`"") | Out-Null
        $newPolicyCommands.AppendLine("next") | Out-Null
        $newPolicyCommands.AppendLine("end") | Out-Null
        if (-not [string]::IsNullOrWhiteSpace($vdomName)) {
            $newPolicyCommands.AppendLine("end") | Out-Null
        }

        # Execute commands
        try {
            Add-Log "Creating new firewall policy..."
            $finalCommands = $newPolicyCommands.ToString()
            $creationResult = Invoke-SSHCommand -SSHSession $script:sshSession -Command $finalCommands
            
            $serverResponse = ($creationResult.Output -join ' ').ToLower()
            $hadError = $false

            if ($serverResponse) {
                Add-Log "Server response: $serverResponse"
                if ($serverResponse -match "command parse error|entry not found|failed|error|invalid") {
                    $hadError = $true
                }
            }

            if ($creationResult.ExitStatus -ne 0 -or $hadError) {
                 Add-Log "Error: Failed to clone policy ${policyId}. Check server response above."
            } else {
                 Add-Log "Successfully cloned policy ${policyId}. The new policy is disabled."
            }
        }
        catch {
            Add-Log "A critical error occurred while creating policy ${policyId}: $($_.Exception.Message)"
        }
    }
    Add-Log "Firewall policy cloning process completed. You can now press 'Fetch Policies' to refresh the list."
})

# --- Cloning Section Search Events ---
$searchFwCloningButton.Add_Click({
    if ($script:allFirewallPolicies.Count -eq 0) {
        Add-Log "Please fetch policies first before searching."
        return
    }
    $searchTerm = $searchFwCloningTextBox.Text
    $searchType = $searchFwCloningComboBox.SelectedItem
    if ([string]::IsNullOrWhiteSpace($searchTerm)) { return }

    Add-Log "Searching policies in cloning section where '$searchType' contains '$searchTerm'..."
    $filteredPolicies = switch ($searchType) {
        "ID"   { $script:allFirewallPolicies | Where-Object { $_ -match "ID: $searchTerm\b" } }
        "Name" { $script:allFirewallPolicies | Where-Object { $_ -match "Name: .*$([regex]::Escape($searchTerm)).*" } }
    }
    $fwPoliciesCheckedListBox.Items.Clear()
    $fwPoliciesCheckedListBox.Items.AddRange($filteredPolicies)
    Add-Log "Found $($filteredPolicies.Count) results."
})

$clearFwCloningSearchButton.Add_Click({
    Add-Log "Clearing search in cloning section."
    $searchFwCloningTextBox.Text = ""
    $fwPoliciesCheckedListBox.Items.Clear()
    $fwPoliciesCheckedListBox.Items.AddRange($script:allFirewallPolicies)
})


# --- Policy Status Management Events ---

$searchMgmtButton.Add_Click({
    if ($script:allFirewallPolicies.Count -eq 0) {
        Add-Log "Please fetch policies first before searching."
        return
    }

    $searchTerm = $searchMgmtTextBox.Text
    $searchType = $searchMgmtComboBox.SelectedItem
    if ([string]::IsNullOrWhiteSpace($searchTerm)) { 
        $statusMgmtCheckedListBox.Items.Clear()
        $statusMgmtCheckedListBox.Items.AddRange($script:allFirewallPolicies)
        return
    }

    Add-Log "Searching policies where '$searchType' contains '$searchTerm'..."
    $filteredPolicies = switch ($searchType) {
        "ID"   { $script:allFirewallPolicies | Where-Object { $_ -match "ID: $searchTerm\b" } }
        "Name" { $script:allFirewallPolicies | Where-Object { $_ -match "Name: .*$([regex]::Escape($searchTerm)).*" } }
    }
    $statusMgmtCheckedListBox.Items.Clear()
    $statusMgmtCheckedListBox.Items.AddRange($filteredPolicies)
    Add-Log "Found $($filteredPolicies.Count) results."
})

$selectAllMgmtButton.Add_Click({
    for ($i = 0; $i -lt $statusMgmtCheckedListBox.Items.Count; $i++) {
        $statusMgmtCheckedListBox.SetItemChecked($i, $true)
    }
})

$deselectAllMgmtButton.Add_Click({
    for ($i = 0; $i -lt $statusMgmtCheckedListBox.Items.Count; $i++) {
        $statusMgmtCheckedListBox.SetItemChecked($i, $false)
    }
})

$enableSelectedButton.Add_Click({
    $selectedPolicies = $statusMgmtCheckedListBox.CheckedItems
    if ($selectedPolicies.Count -eq 0) {
        Add-Log "No policies selected to enable."
        return
    }

    $policyIds = $selectedPolicies | ForEach-Object { ($_ -split ' ')[1] }
    $idString = $policyIds -join ' '
    
    Add-Log "Preparing to enable policies: $idString"

    $vdomName = $vdomTextBox.Text
    $commandPrefix = Get-CommandPrefix -vdomName $vdomName

    $enableCommands = New-Object System.Text.StringBuilder
    $enableCommands.AppendLine($commandPrefix) | Out-Null
    $enableCommands.AppendLine("config firewall policy") | Out-Null
    $enableCommands.AppendLine("edit $idString") | Out-Null
    $enableCommands.AppendLine("set status enable") | Out-Null
    $enableCommands.AppendLine("end") | Out-Null
    if ($commandPrefix) { $enableCommands.AppendLine("end") | Out-Null }

    try {
        Add-Log "Sending enable command..."
        $finalCommands = $enableCommands.ToString()
        $result = Invoke-SSHCommand -SSHSession $script:sshSession -Command $finalCommands
        
        $serverResponse = ($result.Output -join ' ').ToLower()
        $hadError = $false

        if ($serverResponse) {
            Add-Log "Server response: $serverResponse"
            if ($serverResponse -match "command parse error|entry not found|failed|error|invalid") {
                $hadError = $true
            }
        }

        if ($result.ExitStatus -ne 0 -or $hadError) {
             Add-Log "Error: Failed to enable policies. Check server response."
        } else {
             Add-Log "Successfully enabled selected policies."
        }
    }
    catch {
        Add-Log "A critical error occurred while enabling policies: $($_.Exception.Message)"
    }
})

$disableSelectedButton.Add_Click({
    $selectedPolicies = $statusMgmtCheckedListBox.CheckedItems
    if ($selectedPolicies.Count -eq 0) {
        Add-Log "No policies selected to disable."
        return
    }

    $policyIds = $selectedPolicies | ForEach-Object { ($_ -split ' ')[1] }
    $idString = $policyIds -join ' '
    
    Add-Log "Preparing to disable policies: $idString"

    $vdomName = $vdomTextBox.Text
    $commandPrefix = Get-CommandPrefix -vdomName $vdomName

    $disableCommands = New-Object System.Text.StringBuilder
    $disableCommands.AppendLine($commandPrefix) | Out-Null
    $disableCommands.AppendLine("config firewall policy") | Out-Null
    $disableCommands.AppendLine("edit $idString") | Out-Null
    $disableCommands.AppendLine("set status disable") | Out-Null
    $disableCommands.AppendLine("end") | Out-Null
    if ($commandPrefix) { $disableCommands.AppendLine("end") | Out-Null }

    try {
        Add-Log "Sending disable command..."
        $finalCommands = $disableCommands.ToString()
        $result = Invoke-SSHCommand -SSHSession $script:sshSession -Command $finalCommands
        
        $serverResponse = ($result.Output -join ' ').ToLower()
        $hadError = $false

        if ($serverResponse) {
            Add-Log "Server response: $serverResponse"
            if ($serverResponse -match "command parse error|entry not found|failed|error|invalid") {
                $hadError = $true
            }
        }

        if ($result.ExitStatus -ne 0 -or $hadError) {
             Add-Log "Error: Failed to disable policies. Check server response."
        } else {
             Add-Log "Successfully disabled selected policies."
        }
    }
    catch {
        Add-Log "A critical error occurred while disabling policies: $($_.Exception.Message)"
    }
})

# --- Policy Route Events ---

# Fetch Policy Routes Button Click Event
$fetchRoutesButton.Add_Click({
    Add-Log "Fetching policy routes..."
    $routePoliciesCheckedListBox.Items.Clear()
    $routeStatusMgmtCheckedListBox.Items.Clear()
    $script:allPolicyRoutes.Clear()
    
    try {
        $vdomName = $vdomTextBox.Text
        $commandPrefix = Get-CommandPrefix -vdomName $vdomName
        
        $command = "${commandPrefix}config system console`nset output standard`nend`nshow router policy"
        $output = Invoke-SSHCommand -SSHSession $script:sshSession -Command $command
        
        $routes = ($output.Output -join "`n") -split '(?=edit \d+)'
        
        foreach ($route in $routes) {
            if ($route -match 'edit (\d+)') {
                $routeId = $matches[1]
                $details = "ID: $routeId"
                if ($route -match 'set input-device "([^"]+)"') { $details += " | In: $($matches[1])" }
                if ($route -match 'set output-device "([^"]+)"') { $details += " | Out: $($matches[1])" }
                if ($route -match 'set src "([^"]+)"') { $details += " | Src: $($matches[1])" }
                if ($route -match 'set dst "([^"]+)"') { $details += " | Dst: $($matches[1])" }
                if ($route -match 'set gateway "([^"]+)"') { $details += " | GW: $($matches[1])" }
                $script:allPolicyRoutes.Add($details)
            }
        }
        $routePoliciesCheckedListBox.Items.AddRange($script:allPolicyRoutes)
        $routeStatusMgmtCheckedListBox.Items.AddRange($script:allPolicyRoutes)
        Add-Log "Fetched $($script:allPolicyRoutes.Count) routes."
    }
    catch {
        Add-Log "An error occurred while fetching routes: $($_.Exception.Message)"
    }
})

# Clone Policy Routes Button Click Event
$copyRoutesButton.Add_Click({
    $selectedRoutes = $routePoliciesCheckedListBox.CheckedItems
    if ($selectedRoutes.Count -eq 0) {
        Add-Log "No policy routes selected for cloning."
        return
    }

    $vdomName = $vdomTextBox.Text
    $commandPrefix = Get-CommandPrefix -vdomName $vdomName

    # Fetch available interfaces once
    Add-Log "Fetching available interfaces..."
    try {
        $interfacesCommand = "${commandPrefix}config system console`nset output standard`nend`nshow system interface"
        $interfacesOutput = Invoke-SSHCommand -SSHSession $script:sshSession -Command $interfacesCommand
        
        $interfaces = [System.Collections.Generic.List[string]]::new()
        $fullOutput = $interfacesOutput.Output -join "`n"
        $interfaceBlocks = $fullOutput -split '(?=edit "*)'
        foreach ($block in $interfaceBlocks) {
            if ($block -match 'edit "([^"]+)"') {
                $interfaces.Add($matches[1])
            }
        }
    }
    catch {
        Add-Log "Failed to fetch interfaces. Cannot proceed."
        return
    }
    
    if ($interfaces.Count -eq 0) {
        Add-Log "Error: No interfaces found. Check device configuration."
        return
    }

    $dialogTitle = "Select new interfaces for all selected routes"
    $newRouteInterfaces = Show-RouteInterfacesDialog -Title $dialogTitle -interfaces $interfaces
        
    if ($null -eq $newRouteInterfaces) {
        Add-Log "Route cloning process cancelled."
        return
    }
    
    $newInputDevice = $newRouteInterfaces.Input
    $newOutputDevice = $newRouteInterfaces.Output
    Add-Log "Applying new interfaces to all routes: Input='$newInputDevice', Output='$newOutputDevice'"

    foreach ($selectedRoute in $selectedRoutes) {
        $routeId = ($selectedRoute -split ' ')[1]
        Add-Log "Preparing to clone policy route ID $routeId..."

        # Fetch original route config
        $routeConfigCommand = "${commandPrefix}config system console`nset output standard`nend`nshow router policy $routeId"
        $routeConfigOutput = Invoke-SSHCommand -SSHSession $script:sshSession -Command $routeConfigCommand
        $routeConfigLines = $routeConfigOutput.Output

        # Build new route commands
        $newRouteCommands = New-Object System.Text.StringBuilder
        if (-not [string]::IsNullOrWhiteSpace($vdomName)) {
            $newRouteCommands.AppendLine("config vdom") | Out-Null
            $newRouteCommands.AppendLine("edit `"$vdomName`"") | Out-Null
        }
        $newRouteCommands.AppendLine("config router policy") | Out-Null
        $newRouteCommands.AppendLine("edit 0") | Out-Null

        foreach ($line in $routeConfigLines) {
            $trimmedLine = $line.Trim()

            if (-not ($trimmedLine -match '^set\s+\S+')) { continue }

            if ($trimmedLine.StartsWith("set input-device")) {
                $newRouteCommands.AppendLine("set input-device `"$newInputDevice`"") | Out-Null
            }
            elseif ($trimmedLine.StartsWith("set output-device")) {
                $newRouteCommands.AppendLine("set output-device `"$newOutputDevice`"") | Out-Null
            }
            elseif ($trimmedLine.StartsWith("set seq-num")) { # Ignore
            }
            else {
                $newRouteCommands.AppendLine($trimmedLine) | Out-Null
            }
        }
        
        $newRouteCommands.AppendLine("set status disable") | Out-Null
        $newRouteCommands.AppendLine("next") | Out-Null
        $newRouteCommands.AppendLine("end") | Out-Null
        if (-not [string]::IsNullOrWhiteSpace($vdomName)) {
            $newRouteCommands.AppendLine("end") | Out-Null
        }

        # Execute commands
        try {
            Add-Log "Creating new policy route..."
            $finalCommands = $newRouteCommands.ToString()
            $creationResult = Invoke-SSHCommand -SSHSession $script:sshSession -Command $finalCommands
            
            $serverResponse = ($creationResult.Output -join ' ').ToLower()
            $hadError = $false

            if ($serverResponse) {
                Add-Log "Server response: $serverResponse"
                if ($serverResponse -match "command parse error|entry not found|failed|error|invalid") {
                    $hadError = $true
                }
            }

            if ($creationResult.ExitStatus -ne 0 -or $hadError) {
                 Add-Log "Error: Failed to clone route ${routeId}. Check server response above."
            } else {
                 Add-Log "Successfully cloned route ${routeId}. The new route is disabled."
            }
        }
        catch {
            Add-Log "A critical error occurred while creating route ${routeId}: $($_.Exception.Message)"
        }
    }
    Add-Log "Policy route cloning process completed. You can now press 'Fetch Routes' to refresh the list."
})

# --- Cloning Section Search Events (Policy Routes) ---
$searchRouteCloningButton.Add_Click({
    if ($script:allPolicyRoutes.Count -eq 0) {
        Add-Log "Please fetch routes first before searching."
        return
    }
    $searchTerm = $searchRouteCloningTextBox.Text
    $searchType = $searchRouteCloningComboBox.SelectedItem
    if ([string]::IsNullOrWhiteSpace($searchTerm)) { return }

    Add-Log "Searching routes in cloning section where '$searchType' contains '$searchTerm'..."
    $filteredRoutes = switch ($searchType) {
        "ID"   { $script:allPolicyRoutes | Where-Object { $_ -match "ID: $searchTerm\b" } }
        "Src"  { $script:allPolicyRoutes | Where-Object { $_ -match "Src: .*$([regex]::Escape($searchTerm)).*" } }
        "Dst"  { $script:allPolicyRoutes | Where-Object { $_ -match "Dst: .*$([regex]::Escape($searchTerm)).*" } }
    }
    $routePoliciesCheckedListBox.Items.Clear()
    $routePoliciesCheckedListBox.Items.AddRange($filteredRoutes)
    Add-Log "Found $($filteredRoutes.Count) results."
})

$clearRouteCloningSearchButton.Add_Click({
    Add-Log "Clearing search in route cloning section."
    $searchRouteCloningTextBox.Text = ""
    $routePoliciesCheckedListBox.Items.Clear()
    $routePoliciesCheckedListBox.Items.AddRange($script:allPolicyRoutes)
})


# --- Policy Route Status Management Events ---

$searchRouteMgmtButton.Add_Click({
    if ($script:allPolicyRoutes.Count -eq 0) {
        Add-Log "Please fetch routes first before searching."
        return
    }

    $searchTerm = $searchRouteMgmtTextBox.Text
    $searchType = $searchRouteMgmtComboBox.SelectedItem
    if ([string]::IsNullOrWhiteSpace($searchTerm)) { 
        $routeStatusMgmtCheckedListBox.Items.Clear()
        $routeStatusMgmtCheckedListBox.Items.AddRange($script:allPolicyRoutes)
        return
    }

    Add-Log "Searching routes where '$searchType' contains '$searchTerm'..."
    $filteredRoutes = switch ($searchType) {
        "ID"   { $script:allPolicyRoutes | Where-Object { $_ -match "ID: $searchTerm\b" } }
        "Src"  { $script:allPolicyRoutes | Where-Object { $_ -match "Src: .*$([regex]::Escape($searchTerm)).*" } }
        "Dst"  { $script:allPolicyRoutes | Where-Object { $_ -match "Dst: .*$([regex]::Escape($searchTerm)).*" } }
    }
    $routeStatusMgmtCheckedListBox.Items.Clear()
    $routeStatusMgmtCheckedListBox.Items.AddRange($filteredRoutes)
    Add-Log "Found $($filteredRoutes.Count) results."
})

$selectAllRouteMgmtButton.Add_Click({
    for ($i = 0; $i -lt $routeStatusMgmtCheckedListBox.Items.Count; $i++) {
        $routeStatusMgmtCheckedListBox.SetItemChecked($i, $true)
    }
})

$deselectAllRouteMgmtButton.Add_Click({
    for ($i = 0; $i -lt $routeStatusMgmtCheckedListBox.Items.Count; $i++) {
        $routeStatusMgmtCheckedListBox.SetItemChecked($i, $false)
    }
})

$enableSelectedRoutesButton.Add_Click({
    $selectedRoutes = $routeStatusMgmtCheckedListBox.CheckedItems
    if ($selectedRoutes.Count -eq 0) {
        Add-Log "No policy routes selected to enable."
        return
    }

    $routeIds = $selectedRoutes | ForEach-Object { ($_ -split ' ')[1] }
    $idString = $routeIds -join ' '
    
    Add-Log "Preparing to enable policy routes: $idString"

    $vdomName = $vdomTextBox.Text
    $commandPrefix = Get-CommandPrefix -vdomName $vdomName

    $enableCommands = New-Object System.Text.StringBuilder
    $enableCommands.AppendLine($commandPrefix) | Out-Null
    $enableCommands.AppendLine("config router policy") | Out-Null
    $enableCommands.AppendLine("edit $idString") | Out-Null
    $enableCommands.AppendLine("set status enable") | Out-Null
    $enableCommands.AppendLine("end") | Out-Null
    if ($commandPrefix) { $enableCommands.AppendLine("end") | Out-Null }

    try {
        Add-Log "Sending enable command for routes..."
        $finalCommands = $enableCommands.ToString()
        $result = Invoke-SSHCommand -SSHSession $script:sshSession -Command $finalCommands
        
        $serverResponse = ($result.Output -join ' ').ToLower()
        $hadError = $false

        if ($serverResponse) {
            Add-Log "Server response: $serverResponse"
            if ($serverResponse -match "command parse error|entry not found|failed|error|invalid") {
                $hadError = $true
            }
        }

        if ($result.ExitStatus -ne 0 -or $hadError) {
             Add-Log "Error: Failed to enable policy routes. Check server response."
        } else {
             Add-Log "Successfully enabled selected policy routes."
        }
    }
    catch {
        Add-Log "A critical error occurred while enabling policy routes: $($_.Exception.Message)"
    }
})

$disableSelectedRoutesButton.Add_Click({
    $selectedRoutes = $routeStatusMgmtCheckedListBox.CheckedItems
    if ($selectedRoutes.Count -eq 0) {
        Add-Log "No policy routes selected to disable."
        return
    }

    $routeIds = $selectedRoutes | ForEach-Object { ($_ -split ' ')[1] }
    $idString = $routeIds -join ' '
    
    Add-Log "Preparing to disable policy routes: $idString"

    $vdomName = $vdomTextBox.Text
    $commandPrefix = Get-CommandPrefix -vdomName $vdomName

    $disableCommands = New-Object System.Text.StringBuilder
    $disableCommands.AppendLine($commandPrefix) | Out-Null
    $disableCommands.AppendLine("config router policy") | Out-Null
    $disableCommands.AppendLine("edit $idString") | Out-Null
    $disableCommands.AppendLine("set status disable") | Out-Null
    $disableCommands.AppendLine("end") | Out-Null
    if ($commandPrefix) { $disableCommands.AppendLine("end") | Out-Null }

    try {
        Add-Log "Sending disable command for routes..."
        $finalCommands = $disableCommands.ToString()
        $result = Invoke-SSHCommand -SSHSession $script:sshSession -Command $finalCommands
        
        $serverResponse = ($result.Output -join ' ').ToLower()
        $hadError = $false

        if ($serverResponse) {
            Add-Log "Server response: $serverResponse"
            if ($serverResponse -match "command parse error|entry not found|failed|error|invalid") {
                $hadError = $true
            }
        }

        if ($result.ExitStatus -ne 0 -or $hadError) {
             Add-Log "Error: Failed to disable policy routes. Check server response."
        } else {
             Add-Log "Successfully disabled selected policy routes."
        }
    }
    catch {
        Add-Log "A critical error occurred while disabling policy routes: $($_.Exception.Message)"
    }
})

# Form Closing Event
$mainForm.Add_Closing({
    if ($script:sshSession -and $script:sshSession.Connected) {
        Add-Log "Closing SSH connection..."
        Remove-SSHSession -SSHSession $script:sshSession
        Add-Log "Connection closed."
    }
})

# Form Load Event
$mainForm.Add_Load({
    # Load logos when the form loads
    Load-ImageFromUrl -PictureBox $fortinetLogoBox -Url "https://www.fortinet.com/content/dam/fortinet/images/logos/fortinet-logo-red.png"
    Load-ImageFromUrl -PictureBox $freeMindLogoBox -Url "https://i.imgur.com/your-logo-url.png" # Replace with a stable URL for your logo
})

# Show the form
[void]$mainForm.ShowDialog()
