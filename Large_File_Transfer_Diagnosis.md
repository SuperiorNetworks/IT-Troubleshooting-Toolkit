# Diagnosis and Recommendations: Large File (18GB+) FTP Transfer Stalls

## Executive Summary
The issue of FTP transfers stalling at 18GB+ is a known limitation of the FTP protocol when operating over NAT (Network Address Translation) routers and stateful firewalls. While the `ftp_sync_tool.ps1` script currently implements keepalives (`FtpPingType=1 FtpPingInterval=10`), these are often insufficient for extremely large files due to how FTP separates control and data channels.

This report outlines the root cause of the stalls, provides immediate mitigation strategies within the current FTP framework, and recommends alternative transfer mechanisms better suited for large StorageCraft backup files.

## Root Cause Analysis: The FTP Control Channel Timeout

FTP uses two separate TCP connections:
1. **Control Channel (Port 21):** Used for sending commands and receiving replies.
2. **Data Channel (Random High Port):** Used for the actual file transfer.

During a large file transfer (e.g., an 18GB `.spf` file), the data channel is highly active, but the **control channel remains completely idle** until the transfer finishes. 

Many enterprise firewalls and NAT routers have strict idle timeout policies for TCP connections (often 10 to 60 minutes). Because the control channel is idle during the long transfer, the firewall silently drops the control connection. 

When the 18GB file finishes transferring on the data channel, the server attempts to send a `226 Transfer Complete` message over the control channel. Since the firewall dropped the connection, the message never reaches the client (WinSCP). WinSCP waits indefinitely (or until its own timeout) and eventually reports a "Timeout detected (control connection)" error, causing the script to stall or fail, even though the file may have actually reached the server.

### Why Current Keepalives Fail
The current script uses `-rawsettings FtpPingType=1 FtpPingInterval=10` to send NOOP (No Operation) commands over the control channel every 10 seconds. However, some FTP servers (like older versions of FileZilla Server) or strict firewalls ignore or block these NOOP packets during an active data transfer, rendering the keepalive ineffective.

## Immediate Mitigation Strategies (FTP/WinSCP)

If you must continue using FTP, the following adjustments can help mitigate the issue:

### 1. Implement Speed Limiting
Paradoxically, limiting the upload speed can sometimes prevent stalls. Some firewalls drop connections if they detect a single stream monopolizing bandwidth for too long without control traffic.
**Implementation:** Add the `-speed` parameter to the WinSCP `put` command in `ftp_sync_tool.ps1`.
```powershell
put -speed=50000 "local_file.spf"
```

### 2. Adjust WinSCP Timeout and Buffer Settings
Modifying WinSCP's internal buffer and timeout settings can improve resilience.
**Implementation:** Update the `-rawsettings` in the script:
```powershell
open ftp://user:pass@server/ -rawsettings FtpPingType=1 FtpPingInterval=10 SendBuf=0 SshSimple=0
```
*(Setting `SendBuf=0` forces WinSCP to rely on the OS TCP buffer, which can sometimes bypass WinSCP-specific timeout issues).*

### 3. Server-Side Adjustments (FileZilla Server)
If you have access to the FileZilla Server at `ftp.sndayton.com`:
- Increase the **"No Transfer Timeout"** and **"Login Timeout"** settings to their maximum values (e.g., 9999 seconds).
- Ensure the passive port range is explicitly defined and forwarded through the server's firewall.

## Recommended Alternative Transfer Mechanisms

FTP is fundamentally ill-suited for 18GB+ files over WAN links. For reliable replication of large StorageCraft backups, consider the following alternatives:

### 1. SFTP (SSH File Transfer Protocol) - **Highly Recommended**
Unlike FTP, SFTP uses a **single** TCP connection (Port 22) for both control commands and data transfer. Because data is constantly flowing over this single connection, firewalls and NAT routers will not drop it due to idle timeouts.

**Pros:**
- Immune to the control channel timeout issue.
- Encrypted and highly secure.
- WinSCP fully supports SFTP with minimal script changes.
- OpenSSH Server is free and can be installed on Windows Server 2012 R2.

**Cons:**
- Requires installing and configuring OpenSSH Server on the destination server.
- Slightly higher CPU overhead due to encryption (though negligible on modern hardware).

**Implementation Path:**
1. Install OpenSSH Server on the Windows Server hosting `ftp.sndayton.com`.
2. Change the WinSCP connection string in the scripts from `ftp://` to `sftp://`.

### 2. BITS (Background Intelligent Transfer Service)
BITS is a built-in Windows service designed specifically for transferring large files asynchronously over HTTP/HTTPS. It is highly resilient to network drops and can resume transfers automatically.

**Pros:**
- Built into Windows (no third-party tools required).
- Automatically resumes interrupted transfers.
- Bandwidth-aware (yields to other network traffic).

**Cons:**
- Requires setting up an IIS/Web server on the destination to receive BITS uploads.
- Can be complex to configure securely.

### 3. Robocopy over VPN/SMB
If a Site-to-Site VPN exists between the client and the server, using `robocopy` over SMB is highly reliable.

**Pros:**
- Built into Windows.
- Excellent retry and resume capabilities (`/Z` switch).
- Very fast over LAN or high-quality VPN.

**Cons:**
- Requires a VPN; exposing SMB directly to the internet is a severe security risk.
- SMB protocol can be chatty and slow over high-latency WAN links.

## Conclusion and Next Steps

The 18GB stall is a fundamental architectural flaw in how FTP interacts with modern firewalls. While tweaking WinSCP settings may provide temporary relief, it is not a permanent fix.

**Recommendation:** Transition the replication mechanism from FTP to **SFTP**. 
SFTP's single-connection architecture completely eliminates the control channel timeout issue. WinSCP already supports SFTP, meaning the PowerShell scripts (`ftp_sync_tool.ps1`, etc.) would only require a minor update to the connection string once the SFTP server is deployed.

If you would like to proceed with SFTP, I can provide a guide on deploying OpenSSH on Windows Server 2012 R2 and update the toolkit scripts to support it.
