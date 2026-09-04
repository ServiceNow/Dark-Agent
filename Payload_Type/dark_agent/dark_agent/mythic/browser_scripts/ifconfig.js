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

        if (jsonData.interfaces !== undefined) {
            const interfaces = jsonData.interfaces;

            const formattedResponse = {
                headers: [
                    { plaintext: "Interface", type: "string", width: 200 },
                    { plaintext: "Status",    type: "string", width: 80 },
                    { plaintext: "IPv4",      type: "string", width: 150 },
                    { plaintext: "Netmask",   type: "string", width: 200 },
                    { plaintext: "Broadcast", type: "string", width: 200 },
                    { plaintext: "IPv6",      type: "string", width: 300 }
                ],
                title: "Network Interfaces",
                rows: []
            };

            function getStatusStyle(status) {
                if (status === "up") {
                    return { color: "#28a745", fontWeight: "bold", icon: "check" };
                } else {
                    return { color: "#dc3545", fontWeight: "bold", icon: "times" };
                }
            }

            function isPrivateIP(ip) {
                if (!ip || ip === "" || ip === "0.0.0.0") return false;
                const parts = ip.split('.');
                if (parts.length !== 4) return false;
                const first = parseInt(parts[0]);
                const second = parseInt(parts[1]);

                if (first === 10) return true;
                if (first === 172 && second >= 16 && second <= 31) return true;
                if (first === 192 && second === 168) return true;
                if (first === 127) return true;
                return false;
            }

            interfaces.forEach(iface => {
                const statusStyle = getStatusStyle(iface.status);

                // Handle case where interface has no IP addresses
                if ((!iface.ipv4_addresses || iface.ipv4_addresses.length === 0) &&
                    (!iface.ipv6_addresses || iface.ipv6_addresses.length === 0)) {
                    formattedResponse.rows.push({
                        Interface: {
                            plaintext: iface.name,
                            copyIcon: true
                        },
                        Status: {
                            plaintext: iface.status.toUpperCase(),
                            cellStyle: { color: statusStyle.color, fontWeight: statusStyle.fontWeight }
                        },
                        "IPv4": { plaintext: "", copyIcon: true },
                        Netmask: { plaintext: "", copyIcon: true },
                        Broadcast: { plaintext: "", copyIcon: true },
                        "IPv6": { plaintext: "", copyIcon: true }
                    });
                    return;
                }

                // Get max addresses for row calculation
                const maxIPv4 = iface.ipv4_addresses ? iface.ipv4_addresses.length : 0;
                const maxIPv6 = iface.ipv6_addresses ? iface.ipv6_addresses.length : 0;
                const maxRows = Math.max(maxIPv4, maxIPv6, 1);

                // Create rows for each IP address
                for (let i = 0; i < maxRows; i++) {
                    const isMainRow = i === 0;
                    const ipv4 = iface.ipv4_addresses && iface.ipv4_addresses[i] ? iface.ipv4_addresses[i] : null;
                    const ipv6 = iface.ipv6_addresses && iface.ipv6_addresses[i] ? iface.ipv6_addresses[i] : null;

                    formattedResponse.rows.push({
                        Interface: {
                            plaintext: isMainRow ? iface.name : "",
                            copyIcon: isMainRow
                        },
                        Status: {
                            plaintext: isMainRow ? iface.status.toUpperCase() : "",
                            cellStyle: isMainRow ? { color: statusStyle.color, fontWeight: statusStyle.fontWeight } : {}
                        },
                        "IPv4": {
                            plaintext: ipv4 ? ipv4.address : "",
                            cellStyle: ipv4 && !isPrivateIP(ipv4.address) ? { color: "#dc3545" } : {},
                            copyIcon: true
                        },
                        Netmask: {
                            plaintext: ipv4 ? ipv4.netmask : "",
                            copyIcon: true
                        },
                        Broadcast: {
                            plaintext: ipv4 ? ipv4.broadcast : "",
                            copyIcon: true
                        },
                        "IPv6": {
                            plaintext: ipv6 ? ipv6.address : "",
                            copyIcon: true
                        }
                    });
                }
            });
            return { table: [formattedResponse] };
        }
    }

    return { 'plaintext': "No response yet from agent..." };
}