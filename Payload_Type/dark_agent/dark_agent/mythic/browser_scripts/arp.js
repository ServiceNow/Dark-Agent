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

        if (jsonData.arp_entries !== undefined) {
            const arpEntries = jsonData.arp_entries;

            const formattedResponse = {
                headers: [
                    { plaintext: "IP Address", type: "string", width: 200 },
                    { plaintext: "MAC Address", type: "string", fill: 250 },
                    { plaintext: "Device", type: "string", width: 100 },
                    { plaintext: "Flags", type: "string", width: 80 }
                ],
                title: "ARP Table",
                rows: []
            };
            arpEntries.forEach(entry => {
                formattedResponse.rows.push({
                    "IP Address": {
                        plaintext: entry.ip_address,
                        copyIcon: true
                    },
                    "MAC Address": {
                        plaintext: entry.mac_address,
                        copyIcon: true
                    },
                    Device: {
                        plaintext: entry.device,
                        copyIcon: true
                    },
                    Flags: {
                        plaintext: entry.flags
                    }
                });
            });

            return { table: [formattedResponse] };
        }
    }

    return { 'plaintext': "No response yet from agent..." };
}