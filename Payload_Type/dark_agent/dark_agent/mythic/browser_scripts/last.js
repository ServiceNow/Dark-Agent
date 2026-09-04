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

        if (jsonData.login_history !== undefined) {
            const loginHistory = jsonData.login_history;

            const formattedResponse = {
                headers: [
                    { plaintext: "User", type: "string", width: 120 },
                    { plaintext: "Terminal", type: "string", width: 100 },
                    { plaintext: "Host", type: "string", width: 200 },
                    { plaintext: "Login Time", type: "string", width: 160 },
                    { plaintext: "Logout Time", type: "string", width: 160 },
                    { plaintext: "Session Type", type: "string", width: 100 }
                ],
                title: "Login History",
                rows: []
            };

            function getSessionTypeStyle(sessionType) {
                switch(sessionType) {
                    case "ssh":
                        return { color: "#007bff"};
                    case "remote":
                        return { color: "#fd7e14"};
                    default:
                        return {};
                }
            }

            function getUserStyle(user) {
                if (user === "root") {
                    return { color: "#dc3545", fontWeight: "bold" };
                }
                return {};
            }

            function getLogoutStyle(logoutTime) {
                if (logoutTime === "still logged in") {
                    return { color: "#28a745", fontWeight: "bold" };
                }
                return {};
            }

            function isRemoteHost(host) {
                if (!host || host === "" || host === "localhost") return false;
                // Check if it's an IP address
                const ipPattern = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
                if (ipPattern.test(host)) {
                    const parts = host.split('.');
                    const first = parseInt(parts[0]);
                    const second = parseInt(parts[1]);
                    // Check if it's a public IP (not private)
                    if (first === 10 || (first === 172 && second >= 16 && second <= 31) ||
                        (first === 192 && second === 168) || first === 127) {
                        return false;
                    }
                    return true;
                }
                return host.includes('.'); // Assume FQDN is remote
            }

            // Sort by login time (most recent first)
            loginHistory.sort((a, b) => new Date(b.login_time) - new Date(a.login_time));

            loginHistory.forEach(entry => {
                const sessionStyle = getSessionTypeStyle(entry.session_type);
                const userStyle = getUserStyle(entry.user);
                const logoutStyle = getLogoutStyle(entry.logout_time);
                const isRemote = isRemoteHost(entry.host);

                formattedResponse.rows.push({
                    User: {
                        plaintext: entry.user,
                        cellStyle: userStyle,
                        copyIcon: true
                    },
                    Terminal: {
                        plaintext: entry.terminal,
                        copyIcon: true
                    },
                    Host: {
                        plaintext: entry.host || "localhost",
                        cellStyle: isRemote ? { color: "#dc3545", fontWeight: "bold" } : {},
                        copyIcon: entry.host && entry.host !== ""
                    },
                    "Login Time": {
                        plaintext: entry.login_time,
                        cellStyle: { fontFamily: "monospace" },
                        copyIcon: true
                    },
                    "Logout Time": {
                        plaintext: entry.logout_time,
                        cellStyle: { ...logoutStyle, fontFamily: "monospace" },
                        copyIcon: entry.logout_time !== "still logged in" && entry.logout_time !== "system boot"
                    },
                    "Session Type": {
                        plaintext: entry.session_type.toUpperCase(),
                        cellStyle: sessionStyle
                    }
                });
            });

            return { table: [formattedResponse] };
        }
    }

    return { 'plaintext': "No response yet from agent..." };
}