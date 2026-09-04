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

        if (jsonData.mounts !== undefined) {
            const mounts = jsonData.mounts.sort((a, b) => a.mount_point.localeCompare(b.mount_point));

            const formattedResponse = {
                headers: [
                    { plaintext: "Device", type: "string", width: 200 },
                    { plaintext: "Mount Point", type: "string", width: 150 },
                    { plaintext: "Filesystem", type: "string", width: 100 },
                    { plaintext: "Options", type: "string", fillWidth: true },
                    { plaintext: "Security", type: "string", width: 120 }
                ],
                title: "Mounted Filesystems",
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
                else if (fs === 'nfsd' || fs === 'cifs' || fs === 'smb' || fs === 'smbfs') {
                    return { color: "#ffc107", fontWeight: "bold", icon: "network" };
                }
                // Memory/temporary filesystems
                else if (fs === 'tmpfs' || fs === 'devtmpfs' || fs === 'ramfs') {
                    return { fontWeight: "normal", icon: "memory" };
                }
                // System/virtual filesystems
                else if (fs === 'proc' || fs === 'sysfs' || fs === 'devpts' || fs === 'cgroup' || fs === 'securityfs') {
                    return { fontWeight: "normal", icon: "cog" };
                }
                // Loop/overlay filesystems
                else if (fs === 'overlay' || fs === 'squashfs' || dev.includes('loop')) {
                    return { fontWeight: "normal", icon: "refresh" };
                }
                return { fontWeight: "normal", icon: "folder" };
            }

            function analyzeSecurityOptions(options) {
                const opts = options.toLowerCase();
                const restrictions = [];
                let exploitability = "hardened";
                let color = "#dc3545";
                let icon = "shield";

                if (opts.includes('noexec')) {
                    restrictions.push("noexec");
                }
                if (opts.includes('nosuid')) {
                    restrictions.push("nosuid");
                }
                if (opts.includes('nodev')) {
                    restrictions.push("nodev");
                }
                if (opts.includes('ro')) {
                    restrictions.push("ro");
                }

                if (opts.includes('rw') && !opts.includes('noexec') && !opts.includes('nosuid')) {
                    exploitability = "exploitable";
                    color = "#28a745";
                    icon = "unlock";
                } else if (opts.includes('rw') && (opts.includes('noexec') || opts.includes('nosuid'))) {
                    exploitability = "restricted";
                    color = "#ffc107";
                    icon = "lock";
                } else if (restrictions.length > 0) {
                    exploitability = "hardened";
                    color = "#dc3545";
                    icon = "shield";
                }

                return {
                    level: exploitability,
                    color: color,
                    icon: icon,
                    features: restrictions
                };
            }


            mounts.forEach(mount => {
                const deviceStyle = getDeviceStyle(mount.device, mount.filesystem_type);
                const security = analyzeSecurityOptions(mount.options);

                formattedResponse.rows.push({
                    Device: {
                        plaintext: mount.device,
                        cellStyle: { color: deviceStyle.color, fontWeight: deviceStyle.fontWeight },
                        startIcon: deviceStyle.icon,
                        copyIcon: true
                    },
                    "Mount Point": {
                        plaintext: mount.mount_point,
                        copyIcon: true
                    },
                    Filesystem: {
                        plaintext: mount.filesystem_type
                    },
                    Options: {
                        plaintext: mount.options,
                        copyIcon: true
                    },
                    Security: {
                        plaintext: security.features.length > 0 ? `${security.level.toUpperCase()} (${security.features.join(',')})` : security.level.toUpperCase(),
                        cellStyle: {
                            color: security.color,
                            fontWeight: "bold"
                        },
                        startIcon: security.icon
                    }
                });
            });

            return { table: [formattedResponse] };
        }
    }

    return { 'plaintext': "No response yet from agent..." };
}