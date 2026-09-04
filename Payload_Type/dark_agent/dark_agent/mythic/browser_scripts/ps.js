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

        if (jsonData.processes !== undefined) {
            // This is process list JSON format
            const processes = jsonData.processes;

            // Prepare the table structure
            const formattedResponse = {
                headers: [
                    { plaintext: "PID", type: "number", width: 80 },
                    { plaintext: "PPID", type: "number", width: 80 },
                    { plaintext: "User", type: "string", width: 100 },
                    { plaintext: "Command", type: "string", fillWidth: true },
                    { plaintext: "Actions", type: "button", width: 90, disableSort: true }
                ],
                title: "Running Processes",
                rows: []
            };

            // Security-relevant process patterns categorized by threat level
            const edrProcesses = [
                // EDR/AV Solutions (RED - High Threat)
                'falcon-sensor', 'cs-falcon-sensor', 'crowdstrike',
                'falcond',
                'sentinelone', 'sentineld', 's1agent',
                'cbagentd', 'cbdaemon', 'carbonblack',
                'jamf', 'jamfprotect', 'jamfdaemon',
                'littlesnitch', 'lsof', 'blockblock',
                'knockknock', 'reikey', 'oversight',
                'symantec', 'norton', 'sep',
                'mcafee', 'eset', 'kaspersky',
                'bitdefender', 'trend', 'sophos'
            ];

            const sessionProcesses = [
                // Login/Session Processes (BLUE)
                'sshd', 'loginwindow', 'su', 'sudo',
                'dscl', 'securityagent', 'authd',
                'opendirectoryd', 'sessionlogoutd',
                'logind', 'systemd-logind', 'getty',
                'login', 'pam', 'krb5kdc', 'chrome',
                'chromium-browser', 'code', 'ZoomWebviewHost',
                'zoom', 'xorg', 'gnome-shell', 'ssh'
            ];

            const virtualizationProcesses = [
                // Virtualization/Container Detection (PURPLE - Environment Analysis)
                'vmware-tools', 'vmtoolsd', 'vmware',
                'vboxservice', 'vboxtray', 'virtualbox',
                'docker', 'dockerd', 'containerd',
                'qemu-guest-agent', 'qemu', 'kvm',
                'xen', 'xenstore', 'parallels', 'vboxsvc'
            ];

            const monitoringProcesses = [
                // Security/Monitoring/Network Tools (ORANGE - Monitoring Threat)
                'osquery', 'osqueryd', 'auditd', 'audisp',
                'rsyslogd', 'syslog-ng', 'journalctl',
                'splunkd', 'splunk', 'universalforwarder',
                'elastic-agent', 'filebeat', 'metricbeat',
                'logstash', 'kibana', 'fluentd',
                'tcpdump', 'wireshark', 'tshark',
                'nmap', 'netstat', 'ss', 'lsof',
                'strace', 'ltrace', 'dtrace',
                'iftop', 'nethogs', 'bandwhich'
            ];

            // Function to categorize and style processes
            function categorizeProcess(processName) {
                const name = processName.toLowerCase();

                if (edrProcesses.includes(name)) {
                    // RED
                    return { color: "#FC7786", fontWeight: "bold", icon: "skull", category: "EDR/AV" };
                }
                if (sessionProcesses.includes(name)) {
                    // LIGHT BLUE
                    return { color: "#24C2CE", fontWeight: "bold", icon: "user", category: "Session" };
                }
                if (virtualizationProcesses.includes(name)) {
                    // PURPLE
                    return { color: "#5274FF", fontWeight: "bold", icon: "server", category: "Virtualization" };
                  }
                if (monitoringProcesses.includes(name)) {
                    // ORANGE
                    return { color: "#FCA822", fontWeight: "bold", icon: "eye", category: "Monitoring" };
                }

                return null; // No special styling
            }

            // Add rows for each process
            processes.forEach(process => {
                // Check if this is a security-relevant process
                const processStyle = categorizeProcess(process.name) || categorizeProcess(process.command_line);
                let commandStyle = {};
                let startIcon = null;

                if (processStyle) {
                    commandStyle = {
                        color: processStyle.color,
                        fontWeight: processStyle.fontWeight
                    };
                    startIcon = processStyle.icon;
                }

                formattedResponse.rows.push({
                    PID: {
                        plaintext: process.process_id,
                        copyIcon: true
                    },
                    PPID: {
                        plaintext: process.parent_process_id,
                        copyIcon: true
                    },
                    User: {
                        plaintext: process.user,
                    },
                    Command: {
                        plaintext: process.command_line,
                        cellStyle: commandStyle,
                        startIcon: startIcon,
                        copyIcon: true
                    },
                    Actions: {
                        button: {
                            name: "Actions",
                            type: "menu",
                            value: [
                                {
                                    name: "Process Details",
                                    type: "dictionary",
                                    value: {
                                        "PID": process.process_id,
                                        "PPID": process.parent_process_id || "N/A",
                                        "User": process.user || "N/A",
                                        "Name": process.name || "N/A",
                                        "BinPath": process.bin_path || "N/A",
                                        "Command": process.command_line,
                                        "Start Time": process.start_time || "N/A"
                                    },
                                    leftColumnTitle: "Property",
                                    rightColumnTitle: "Value",
                                    title: `Process ${process.process_id} Details`
                                },
                                {
                                    name: "Kill Process",
                                    type: "task",
                                    ui_feature: "process_browser:kill",
                                    parameters: process.process_id,
                                    disabled: false
                                }
                            ]
                        }
                    }
                });
            });

            return { table: [formattedResponse] };
        }
    }

    return { 'plaintext': "No response yet from agent..." };
}