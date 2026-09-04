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

        if (jsonData.jobs !== undefined) {
            const jobs = jsonData.jobs;

            const formattedResponse = {
                headers: [
                    { plaintext: "Task ID", type: "string", fillWidth: true },
                    { plaintext: "BOF Name", type: "string", width: 150 },
                    { plaintext: "Duration", type: "string", width: 120 },
                    { plaintext: "Start Time", type: "string", width: 180 }
                ],
                title: "Active BOF Jobs",
                rows: []
            };

            function getDurationStyle(durationSeconds) {
                if (durationSeconds > 300) { // > 5 minutes
                    return { color: "#dc3545", fontWeight: "bold" }; // Red for long-running
                } else if (durationSeconds > 60) { // > 1 minute
                    return { color: "#ffc107", fontWeight: "bold" }; // Yellow for moderate
                } else {
                    return { color: "#28a745", fontWeight: "normal" }; // Green for recent
                }
            }

            jobs.forEach(job => {
                const durationStyle = getDurationStyle(job.duration_seconds);

                formattedResponse.rows.push({
                    "Task ID": {
                        plaintext: job.task_id,
                        copyIcon: true
                    },
                    "BOF Name": {
                        plaintext: job.bof_name,
                        copyIcon: true
                    },
                    "Duration": {
                        plaintext: job.duration,
                        cellStyle: { color: durationStyle.color, fontWeight: durationStyle.fontWeight }
                    },
                    "Start Time": {
                        plaintext: job.start_time,
                        copyIcon: true
                    }
                });
            });

            return { table: [formattedResponse] };
        }
    }

    return { 'plaintext': "No response yet from agent..." };
}