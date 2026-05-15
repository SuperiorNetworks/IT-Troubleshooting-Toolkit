# Large File Transfer (18GB+) Fix Guide

This guide outlines the four-layer fix to permanently resolve the 18GB+ FTP transfer stall issue between the client sites and `ftp.sndayton.com`.

## Layer 1: Client-Side Script Improvements (Completed)
The `ftp_sync_tool.ps1` script has been updated to include `SendBuf=0` and `SshSimple=0` in the WinSCP raw settings. 
- `SendBuf=0` forces WinSCP to rely on the Windows OS TCP buffer rather than its own internal buffer, which prevents WinSCP from internally timing out while waiting for the OS to flush data to the network.

## Layer 2: FileZilla Server Settings (Action Required)
Since you control the FileZilla Server (0.9.60 beta) at `ftp.sndayton.com`, you must adjust the server-side timeouts to prevent it from dropping the control connection during the long 18GB upload.

1. Open the **FileZilla Server Interface**.
2. Go to **Edit > Settings**.
3. Under **General settings > Timeouts**:
   - Set **Connection timeout** to `0` (No timeout) or `9999`.
   - Set **No Transfer timeout** to `0` (No timeout) or `9999`.
   - Set **Login timeout** to `9999`.
4. Under **Passive mode settings**:
   - Ensure **Use custom port range** is checked.
   - Set a range (e.g., `50000 - 51000`).
   - *Crucial:* Ensure this exact port range is forwarded through the UDM firewall at the server site.

## Layer 3: UDM Firewall Tuning (Action Required)
Ubiquiti UDM firewalls have strict stateful TCP timeouts. If the control connection (Port 21) is idle for too long, the UDM will drop it from its state table.

1. Log into the **UDM Pro/SE** at the **Server Site** (`ftp.sndayton.com`).
2. Go to **Settings > Security > Firewall Rules**.
3. Ensure you have a Port Forwarding rule for Port 21 AND the Passive Port Range (e.g., 50000-51000) pointing to the FileZilla Server IP.
4. *Note:* UDM does not currently expose a GUI option to change the global TCP idle timeout. If the FileZilla Server timeout fixes (Layer 2) do not resolve the issue, you MUST migrate to SFTP (Layer 4).

---

## Layer 4: The Permanent Fix - Migrate to SFTP (Highly Recommended)
FTP is fundamentally flawed for 18GB files over NAT because it uses two separate connections (Control and Data). SFTP uses a **single connection** (Port 22) for both commands and data. Because data is constantly flowing over this single connection, the UDM firewall will *never* drop it due to an idle timeout.

### Step 1: Install OpenSSH on Windows Server 2012 R2 (`ftp.sndayton.com`)
1. Download the latest OpenSSH release for Windows:
   `https://github.com/PowerShell/Win32-OpenSSH/releases`
2. Extract the `.zip` to `C:\Program Files\OpenSSH`.
3. Open an elevated PowerShell prompt and run:
   ```powershell
   cd "C:\Program Files\OpenSSH"
   powershell.exe -ExecutionPolicy Bypass -File install-sshd.ps1
   ```
4. Open Port 22 in the Windows Firewall:
   ```powershell
   New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
   ```
5. Start the service and set it to Automatic:
   ```powershell
   Start-Service sshd
   Set-Service sshd -StartupType Automatic
   ```

### Step 2: Update the UDM Firewall
1. On the Server UDM, create a Port Forwarding rule for **Port 22** pointing to the Windows Server IP.

### Step 3: Update the Toolkit Script
Once the SFTP server is running, update `ftp_sync_tool.ps1` to use SFTP instead of FTP.
Change line 242, 426, and 455 from:
`open ftp://$($ftpCreds.User):$($ftpCreds.Pass)@$($ftpCreds.Server)/ ...`
To:
`open sftp://$($ftpCreds.User):$($ftpCreds.Pass)@$($ftpCreds.Server)/ -hostkey="*" ...`

*(Note: `-hostkey="*"` blindly accepts the server's SSH key. For better security, replace `*` with the actual host key fingerprint).*
