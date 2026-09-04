function(task, responses) {
    if (task.status.includes("error")) {
        const combined = responses.reduce((prev, cur) => prev + cur, "");
        return { 'plaintext': combined };
    } else if (responses.length > 0) {
        const output = responses.reduce((prev, cur) => prev + cur, "");
        let jsonData;

        try {
          jsonData = JSON.parse(output);
        } catch(error) {
          return { 'plaintext': output };
        }

        if (jsonData.filesystems !== undefined) {
            const filesystems = jsonData.filesystems.sort((a, b) => a.mount_point.localeCompare(b.mount_point));

            const formattedResponse = {
                headers: [
                    { plaintext: "Device", type: "string", width: 200 },
                    { plaintext: "Mount Point", type: "string", fillWidth: true },
                    { plaintext: "Type", type: "string", width: 100 },
                    { plaintext: "Total", type: "size", width: 100 },
                    { plaintext: "Used", type: "size", width: 100 },
                    { plaintext: "Available", type: "size", width: 100 },
                    { plaintext: "Use%", type: "number", width: 80 }
                ],
                title: "Filesystem Usage",
                rows: []
            };

            function getDeviceStyle(device, fsType) {
                const dev = device.toLowerCase();
                const fs = fsType.toLowerCase();

                // Persistent storage filesystems (important for red team)
                if (fs === 'ext4' || fs === 'ext3' || fs === 'ext2' || fs === 'xfs' || fs === 'btrfs' || fs === 'zfs') {
                    return { color: "#28a745", fontWeight: "bold", icon: "hdd" };
                }
                // Windows filesystems
                else if (fs === 'ntfs' || fs === 'fat32' || fs === 'vfat' || fs === 'exfat') {
                    return { color: "#fd7e14", fontWeight: "bold", icon: "hdd" };
                }
                // Network filesystems
                else if (fs === 'nfs' || fs === 'cifs' || fs === 'smb' || fs === 'smbfs') {
                    return { color: "#ffc107", fontWeight: "bold", icon: "network" };
                }
                // Memory/temporary filesystems
                else if (fs === 'tmpfs' || fs === 'devtmpfs' || fs === 'ramfs') {
                    return { color: "#6c757d", fontWeight: "normal", icon: "memory" };
                }
                // System/virtual filesystems
                else if (fs === 'proc' || fs === 'sysfs' || fs === 'devpts' || fs === 'cgroup' || fs === 'securityfs') {
                    return { color: "#6c757d", fontWeight: "normal", icon: "cog" };
                }
                // Loop/overlay filesystems
                else if (fs === 'overlay' || fs === 'squashfs' || dev.includes('loop')) {
                    return { color: "#6c757d", fontWeight: "normal", icon: "refresh" };
                }
                return { color: "#333", fontWeight: "normal", icon: "folder" };
            }

            filesystems.forEach(fs => {
                const deviceStyle = getDeviceStyle(fs.device, fs.filesystem_type);

                formattedResponse.rows.push({
                    Device: {
                        plaintext: fs.device,
                        cellStyle: { color: deviceStyle.color, fontWeight: deviceStyle.fontWeight },
                        startIcon: deviceStyle.icon,
                        copyIcon: true
                    },
                    "Mount Point": {
                        plaintext: fs.mount_point,
                        copyIcon: true
                    },
                    Type: {
                        plaintext: fs.filesystem_type
                    },
                    Total: {
                        plaintext: fs.total_bytes,
                    },
                    Used: {
                        plaintext: fs.used_bytes,
                    },
                    Available: {
                        plaintext: fs.available_bytes,
                    },
                    "Use%": {
                        plaintext: fs.use_percent + "%",
                        cellStyle: {
                            color: fs.use_percent > 80 ? "#dc3545" : fs.use_percent > 60 ? "#fd7e14" : "#28a745",
                            fontWeight: "bold"
                        }
                    }
                });
            });

            return { table: [formattedResponse] };
        }
    }

    return { 'plaintext': "No response yet from agent..." };
}