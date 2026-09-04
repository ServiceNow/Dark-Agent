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

        if (jsonData.routes !== undefined) {
            const routes = jsonData.routes;

            const formattedResponse = {
                headers: [
                    { plaintext: "Destination", type: "string", width: 150 },
                    { plaintext: "Gateway", type: "string", width: 150 },
                    { plaintext: "Netmask", type: "string", width: 150 },
                    { plaintext: "Interface", type: "string", width: 200 },
                    { plaintext: "Metric", type: "number", width: 80 },
                    { plaintext: "Type", type: "string", width: 100 }
                ],
                title: "Routing Table",
                rows: []
            };

            function getRouteTypeStyle(type) {
                switch(type) {
                    case "default":
                        return { color: "#dc3545", fontWeight: "bold" };
                    default:
                        return {};
                }
            }

            function getGatewayStyle(gateway) {
                if (gateway === "0.0.0.0") {
                    return {};
                }
                // Check if it's a private IP
                const parts = gateway.split('.');
                if (parts.length === 4) {
                    const first = parseInt(parts[0]);
                    const second = parseInt(parts[1]);

                    if (first === 10 || (first === 172 && second >= 16 && second <= 31) ||
                        (first === 192 && second === 168)) {
                        return { color: "#17a2b8", fontWeight: "bold" };
                    }
                }
                return { color: "#fd7e14", fontWeight: "bold" };
            }

            function getMetricStyle(metric) {
                return {};
            }

            // Sort routes: default routes first, then by metric
            routes.sort((a, b) => {
                if (a.type === "default" && b.type !== "default") return -1;
                if (a.type !== "default" && b.type === "default") return 1;
                return a.metric - b.metric;
            });

            routes.forEach(route => {
                const typeStyle = getRouteTypeStyle(route.type);
                const gatewayStyle = getGatewayStyle(route.gateway);
                const metricStyle = getMetricStyle(route.metric);

                formattedResponse.rows.push({
                    Destination: {
                        plaintext: route.destination === "0.0.0.0" ? "default" : `${route.destination}/${route.cidr}`,
                        cellStyle: route.destination === "0.0.0.0" ? { color: "#dc3545", fontWeight: "bold" } : {},
                        copyIcon: true
                    },
                    Gateway: {
                        plaintext: route.gateway === "0.0.0.0" ? "direct" : route.gateway,
                        cellStyle: gatewayStyle,
                        copyIcon: route.gateway !== "0.0.0.0"
                    },
                    Netmask: {
                        plaintext: route.netmask,
                        cellStyle: { fontFamily: "monospace" },
                        copyIcon: true
                    },
                    Interface: {
                        plaintext: route.interface,
                        copyIcon: true
                    },
                    Metric: {
                        plaintext: route.metric.toString(),
                        cellStyle: metricStyle
                    },
                    Type: {
                        plaintext: route.type.toUpperCase(),
                        cellStyle: typeStyle
                    }
                });
            });

            return { table: [formattedResponse] };
        }
    }

    return { 'plaintext': "No response yet from agent..." };
}