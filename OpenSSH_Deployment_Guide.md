# OpenSSH Deployment Guide for Windows Server 2012 R2

This guide provides step-by-step instructions for installing and configuring OpenSSH on Windows Server 2012 R2 to enable secure, reliable SFTP file transfers. This is the recommended solution for resolving large file transfer stalls caused by stateful firewall idle timeouts.

## Prerequisites

*   Windows Server 2012 R2
*   Administrator privileges
*   PowerShell 4.0 or later

## Installation Steps

1.  **Download Win32-OpenSSH:**
    *   Navigate to the official GitHub repository: [https://github.com/PowerShell/Win32-OpenSSH/releases](https://github.com/PowerShell/Win32-OpenSSH/releases)
    *   Download the latest `.zip` release for your architecture (e.g., `OpenSSH-Win64.zip`).

2.  **Extract the Files:**
    *   Extract the contents of the `.zip` file to `C:\Program Files\OpenSSH`.

3.  **Install the Service:**
    *   Open an elevated PowerShell prompt (Run as Administrator).
    *   Navigate to the OpenSSH directory:
        ```powershell
        cd "C:\Program Files\OpenSSH"
        ```
    *   Run the installation script:
        ```powershell
        .\install-sshd.ps1
        ```

4.  **Configure the Service:**
    *   Set the `sshd` service to start automatically:
        ```powershell
        Set-Service -Name sshd -StartupType 'Automatic'
        ```
    *   Start the service:
        ```powershell
        Start-Service sshd
        ```

5.  **Configure Windows Firewall:**
    *   Open Port 22 (the default SSH port) in the Windows Firewall to allow incoming connections:
        ```powershell
        New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
        ```

6.  **Configure UDM Firewall (Server Side):**
    *   Log in to your UDM firewall.
    *   Create a Port Forwarding rule to forward Port 22 to the internal IP address of your Windows Server 2012 R2 machine.

## Verification

To verify the installation, you can attempt to connect to the server using an SFTP client (like WinSCP) from another machine, using the server's IP address and Port 22.

## Security Considerations

*   **Authentication:** By default, OpenSSH uses Windows credentials. For enhanced security, consider configuring SSH key-based authentication and disabling password authentication.
*   **Port:** While Port 22 is standard, changing it to a non-standard port can reduce automated scanning attempts. If you change the port, remember to update both the Windows Firewall and UDM Port Forwarding rules accordingly.
