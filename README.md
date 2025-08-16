Advanced FortiGate Cloning & Management Tool

® Developed by Hazem Mohamed - Cybersecurity Engineer | LinkedIn: https://www.linkedin.com/in/hazem-mohamed-03742957/



****This Tool was developed using my skills in PowerShell scripting and enhanced by Google Gemini Flash Pro 2.5****

A powerful PowerShell GUI tool designed to streamline and automate the management of FortiGate firewalls. This tool transforms repetitive, time-consuming tasks into a few simple clicks, significantly boosting productivity and reducing the risk of human error.

What started as a simple policy cloner has evolved into an integrated management hub, built through a collaborative development process.
📸 Screenshot:
<img width="1060" height="1352" alt="Screenshot 2025-08-09 at 10 31 53 PM" src="https://github.com/user-attachments/assets/51a52bc8-0be8-44b6-bf42-5b97941b5d8d" />

<img width="2486" height="198" alt="Screenshot 2025-08-09 at 10 32 07 PM" src="https://github.com/user-attachments/assets/00ba6743-d2b0-458e-a583-681e2e2f61bd" />

**Existing Policies:
**
<img width="2560" height="1352" alt="Screenshot 2025-08-09 at 10 21 22 PM" src="https://github.com/user-attachments/assets/b1151bda-28a4-43c7-b62d-1df62191ef55" />
<img width="2560" height="1352" alt="Screenshot 2025-08-09 at 10 19 51 PM" src="https://github.com/user-attachments/assets/120305ac-69c0-4a06-b7f4-ef3e77c16980" />


<img width="817" height="891" alt="Screenshot 2025-08-10 145215" src="https://github.com/user-attachments/assets/c54e404c-cc28-478c-b41c-3b15371b69f0" />


✨ Key Features

This tool is packed with intelligent features designed for real-world network administration scenarios:

    Bulk Cloning:

        Clone multiple Firewall Policies at once.

        Clone multiple Policy Routes at once.

    Bulk Status Management:

        Enable or Disable multiple Firewall Policies or Policy Routes simultaneously.

    Smart Interface Handling:

        Select new interfaces (input, output, srcintf, dstintf) once and apply the change to all selected items in a single operation.

    Advanced Search & Filtering:

        Instantly find any policy or route by its ID, Name, Source Address, or Destination Address. This allows you to quickly isolate and manage specific rules.

    Intelligent Name Handling:

        Automatically handles long policy names by adding a Copy_of_ prefix and truncating the original name if it exceeds FortiGate's 35-character limit, preventing errors.

    VDOM Aware:

        Full support for Virtual Domains (VDOMs). Simply enter the VDOM name to manage its specific policies and routes.

    Professional & Flexible UI:

        A clean, resizable graphical interface with a scrollable layout that adapts to any screen size.

        Includes a real-time log viewer to monitor all operations.

        Features a "Disconnect" button to safely terminate the SSH session and reset the UI, allowing you to connect to another device without restarting.

⚙️ Requirements

    Windows Operating System (Tested on Windows 10/11 and Windows Server 2016/2019).

    PowerShell 5.1 or higher.

    Posh-SSH PowerShell Module.

🚀 Installation Guide

Follow these simple steps to get the tool up and running.
1. Install the Posh-SSH Module

If you don't have it installed, open PowerShell as an Administrator and run the following command.

    Note for Windows Server 2016: You may need to run [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 first to enable modern security protocols.

Install-Module -Name Posh-SSH -Force

2. Download the Tool

Download the FortiGate-Tool.ps1 script file from this repository.
3. Unblock the Script

For security, Windows may block scripts downloaded from the internet. To unblock it:

    Right-click on the FortiGate-Tool.ps1 file.

    Go to Properties.

    At the bottom of the General tab, check the "Unblock" box and click OK.

4. Run the Tool

Simply right-click on the FortiGate-Tool.ps1 file and select "Run with PowerShell".
📖 How to Use

    Connect:

        Enter the FortiGate's IP Address, your Username, and Password.

        If you use VDOMs, enter the specific VDOM name. Otherwise, leave it blank.

        Click Connect.

    Fetch Data:

        Click "Fetch Policies" to load all firewall policies.

        Click "Fetch Routes" to load all policy routes.

        The policies/routes will appear in both the "Cloning" and "Status Management" sections.

    Clone Policies/Routes:

        In the appropriate "Cloning" section, use the Search feature to find the items you want to copy.

        Check the boxes next to the desired items.

        Click "Clone Selected".

        A dialog box will appear asking you to select the new interface(s).

        The tool will create new, disabled copies with the updated interfaces.

    Manage Status (Enable/Disable):

        In the appropriate "Status Management" section, use the Search feature to find the items you want to manage.

        Check the boxes next to the desired items. Use "Select All" for bulk actions.

        Click "Enable" or "Disable" to change the status of all selected items at once.

    Disconnect:

        When you're finished, click the "Disconnect" button to safely close the session.

🤝 Contribution & Feedback

This tool was born from a real-world need and evolved through iterative feedback. If you have ideas for new features, improvements, or bug reports, please feel free to open an issue or reach out.

Enjoy the tool! :) 




