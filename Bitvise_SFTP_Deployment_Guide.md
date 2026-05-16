# OpenSSH Deployment Guide for Windows Server 2012 R2

This guide provides step-by-step instructions for installing and configuring OpenSSH on Windows Server 2012 R2 to enable secure, reliable SFTP file transfers. This is the recommended solution for resolving large file transfer stalls caused by stateful firewall idle timeouts.

## Prerequisites

- Windows Server 2012 R2

- Administrator privileges

- PowerShell 4.0 or later

## Installation Steps

1. **Download Win32-OpenSSH:**
  - Navigate to the official GitHub repository: [https://github.com/PowerShell/Win32-OpenSSH/releases](https://github.com/PowerShell/Win32-OpenSSH/releases)
  - Download the latest `.zip` release for your architecture (e.g., `OpenSSH-Win64.zip`).

1. **Extract the Files:**
  - Extract the contents of the `.zip` file to `C:\Program Files\OpenSSH`.

1. **Install the Service:**
  - Open an elevated PowerShell prompt (Run as Administrator).
    - Navigate to the OpenSSH directory:
    
       ```
       cd "C:\Program Files\OpenSSH"
       ```
    - Run the installation script:
    
       ```
       .\install-sshd.ps1
       ```

1. **Configure the Service:**
    - Set the `sshd` service to start automatically:
    
       ```
       Set-Service -Name sshd -StartupType 'Automatic''
       ```
    - Start the service:
    
       ```
       Start-Service sshd
       ```

1. **Configure Windows Firewall:**
    - Open Port 22 (the default SSH port) in the Windows Firewall to allow incoming connections:
    
       ```
       New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
       ```

1. **Configure UDM Firewall (Server Side):**
  - Log in to your UDM firewall.
  - Create a Port Forwarding rule to forward Port 22 to the internal IP address of your Windows Server 2012 R2 machine.

## Verification

To verify the installation, you can attempt to connect to the server using an SFTP client (like WinSCP) from another machine, using the server's IP address and Port 22.

## Security Considerations

- **Authentication:** By default, OpenSSH uses Windows credentials. For enhanced security, consider configuring SSH key-based authentication and disabling password authentication.

- **Port:** While Port 22 is standard, changing it to a non-standard port can reduce automated scanning attempts. If you change the port, remember to update both the Windows Firewall and UDM Port Forwarding rules accordingly.


## Managing Connections and Permissions

### Viewing Active Connections

You can monitor active SSH/SFTP connections to your server using several methods:

1. **Using PowerShell (Get-NetTCPConnection):**
   Open an elevated PowerShell prompt and run:
   ```powershell
   Get-NetTCPConnection -LocalPort 22 -State Established
   ```
   This will list all active connections to port 22, showing the remote IP addresses of connected clients.

2. **Using OpenSSH Logs:**
   OpenSSH logs connection events to a file. You can view the log at:
   `C:\ProgramData\ssh\logs\sshd.log`
   *(Note: `C:\ProgramData` is a hidden folder by default).*

3. **Using Windows Event Viewer:**
   OpenSSH can also log to the Windows Event Log.
   - Open **Event Viewer** (`eventvwr.msc`).
   - Navigate to **Applications and Services Logs** -> **OpenSSH** -> **Operational**.
   - Look for Event ID 4 (Connection accepted) and Event ID 5 (Connection closed).

### Setting User Permissions

By default, any Windows user with login rights to the server can connect via SSH. For a dedicated SFTP backup server, you should restrict access to a specific user account and limit their permissions.

1. **Create a Dedicated Backup User:**
   - Open **Computer Management** (`compmgmt.msc`).
   - Go to **Local Users and Groups** -> **Users**.
   - Create a new user (e.g., `sftp_backup`). Set a strong password and check "Password never expires".
   - **Important:** Remove this user from the `Users` group if you want to strictly limit their access, but ensure they have Read/Write NTFS permissions to the `Z:\BackupStore` (or equivalent) directory.

2. **Restrict SSH Access to Specific Users (sshd_config):**
   You must configure OpenSSH to only allow your dedicated backup user(s) to connect.
   - Open the OpenSSH configuration file in a text editor (run as Administrator):
     `C:\ProgramData\ssh\sshd_config`
   - Scroll to the bottom of the file and add the following line:
     ```text
     AllowUsers sftp_backup
     ```
     *(Replace `sftp_backup` with your actual username. You can list multiple users separated by spaces, or use `AllowGroups` to allow an entire Windows group).*
   - Save the file.

3. **Restart the SSH Service:**
   For the changes to take effect, restart the OpenSSH service from an elevated PowerShell prompt:
   ```powershell
   Restart-Service sshd
   ```

4. **(Optional) Restrict to SFTP Only (Chroot):**
   If you want to prevent the `sftp_backup` user from running PowerShell commands and restrict them *only* to the backup directory, you can configure a Chroot directory in `sshd_config`.
   - Add this to the bottom of `C:\ProgramData\ssh\sshd_config`:
     ```text
     Match User sftp_backup
         ChrootDirectory Z:\BackupStore
         ForceCommand internal-sftp
         AllowTcpForwarding no
         X11Forwarding no
     ```
   - **Note:** The ChrootDirectory must have strict NTFS permissions (owned by SYSTEM or Administrators, with no write access for the user on the root folder itself, only on subfolders). This can be complex to set up on Windows, so test thoroughly.
   - Restart the `sshd` service after making changes.
