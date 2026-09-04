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

        if (jsonData.lookups !== undefined) {
            const lookups = jsonData.lookups;
            const nameserver = jsonData.nameserver || "system";

            const formattedResponse = {
                headers: [
                    { plaintext: "Hostname", type: "string", fillWidth: true, disableSort: true },
                    { plaintext: "IPv4", type: "string", width: 200, disableSort: true },
                    { plaintext: "IPv6", type: "string", width: 300, disableSort: true },
                    { plaintext: "Status", type: "string", width: 100, disableSort: true }
                ],
                title: `DNS Lookup Results (using ${nameserver})`,
                rows: []
            };

            function getStatusStyle(status) {
                if (status === "success") {
                    return { color: "#28a745", fontWeight: "bold", icon: "check" };
                } else {
                    return { color: "#dc3545", fontWeight: "bold", icon: "times" };
                }
            }

            lookups.forEach(lookup => {
                const statusStyle = getStatusStyle(lookup.status);

                // Create arrays of all IP addresses
                const ipv4_addresses = lookup.ipv4_addresses || [];
                const ipv6_addresses = lookup.ipv6_addresses || [];

                // Get the maximum number of addresses to determine how many rows we need
                const maxAddresses = Math.max(ipv4_addresses.length, ipv6_addresses.length, 1);

                // Create a row for each IP address
                for (let i = 0; i < maxAddresses; i++) {
                    const isMainRow = i === 0;

                    formattedResponse.rows.push({
                        Hostname: {
                            plaintext: isMainRow ? lookup.hostname : "",
                            copyIcon: isMainRow
                        },
                        "IPv4": {
                            plaintext: ipv4_addresses[i] || "",
                            copyIcon: ipv4_addresses[i] ? true : false
                        },
                        "IPv6": {
                            plaintext: ipv6_addresses[i] || "",
                            copyIcon: ipv6_addresses[i] ? true : false
                        },
                        Status: {
                            plaintext: isMainRow ? lookup.status.toUpperCase() : "",
                            cellStyle: isMainRow ? { color: statusStyle.color, fontWeight: statusStyle.fontWeight } : {},
                            startIcon: isMainRow ? statusStyle.icon : null
                        }
                    });
                }
            });

            return { table: [formattedResponse] };
        }
    }

    return { 'plaintext': "No response yet from agent..." };
}