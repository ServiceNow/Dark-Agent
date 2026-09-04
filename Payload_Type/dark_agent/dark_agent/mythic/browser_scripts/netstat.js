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

        if (jsonData.connections !== undefined) {
            const connections = jsonData.connections;

            const formattedResponse = {
                headers: [
                    { plaintext: "Protocol", type: "string", width: 100 },
                    { plaintext: "Local Address", type: "string", width: 200 },
                    { plaintext: "Local Port", type: "number", width: 100 },
                    { plaintext: "State", type: "string", width: 120 }
                ],
                title: "Network Connections",
                rows: []
            };

            function getProtocolStyle(protocol) {
                if (protocol === "tcp") {
                    return { color: "#5274FF", fontWeight: "bold" };
                } else if (protocol === "udp") {
                    return { color: "#007bff", fontWeight: "bold" };
                } else {
                    return { fontWeight: "normal" };
                }
            }

            function getStateStyle(state) {
                switch(state) {
                    case "ESTABLISHED":
                        return { color: "#28a745", fontWeight: "bold" };
                    case "LISTEN":
                        return { color: "#17a2b8", fontWeight: "bold" };
                }
            }

            function isPrivateIP(ip) {
                if (ip === "0.0.0.0" || ip === "127.0.0.1") return true;
                const parts = ip.split('.');
                if (parts.length !== 4) return false;
                const first = parseInt(parts[0]);
                const second = parseInt(parts[1]);

                // Private IP ranges
                if (first === 10) return true;
                if (first === 172 && second >= 16 && second <= 31) return true;
                if (first === 192 && second === 168) return true;
                return false;
            }

            connections.forEach(conn => {
                const protocolStyle = getProtocolStyle(conn.protocol);
                const stateStyle = getStateStyle(conn.state);

                formattedResponse.rows.push({
                    Protocol: {
                        plaintext: conn.protocol.toUpperCase(),
                        cellStyle: { color: protocolStyle.color, fontWeight: protocolStyle.fontWeight },
                        startIcon: protocolStyle.icon
                    },
                    "Local Address": {
                        plaintext: conn.local_address,
                        copyIcon: true
                    },
                    "Local Port": {
                        plaintext: conn.local_port.toString(),
                        copyIcon: true
                    },
                    State: {
                        plaintext: conn.state,
                        cellStyle: { color: stateStyle.color, fontWeight: stateStyle.fontWeight },
                        startIcon: stateStyle.icon
                    }
                });
            });

            return { table: [formattedResponse] };
        }
    }

    return { 'plaintext': "No response yet from agent..." };
}