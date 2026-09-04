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

        if (jsonData.files !== undefined) {
            // This is file browser JSON format
            const files = jsonData.files;
            const parentPath = jsonData.parent_path || "";
            const dirName = jsonData.name || "";
            const sep = parentPath.includes("/") ? "/" : "\\";

            // Prepare the table structure
            const formattedResponse = {
                headers: [
                    { plaintext: "Name", type: "string", fillWidth: true },
                    { plaintext: "Size", type: "size", width: 100 },
                    { plaintext: "R", type: "string", width: 30 },
                    { plaintext: "W", type: "string", width: 30 },
                    { plaintext: "X", type: "string", width: 30 },
                    { plaintext: "Modified", type: "date", width: 220 },
                    { plaintext: "Actions", type: "button", width: 90, disableSort: true }
                ],
                title: `Contents of ${parentPath === "/" && dirName === "/" ? "/" :
                        parentPath === "/" ? `/${dirName}` :
                        dirName === "/" ? parentPath :
                        `${parentPath}${sep}${dirName}`}`,
                rows: []
            };

            // File type icon mapping
            const archiveFormats = [".zip", ".tar", ".gz", ".rar", ".7z"];
            const scriptFiles = [".sh", ".py", ".rb", ".js", ".cr", ".c", ".cpp", ".h"];
            const configFiles = [".json", ".yml", ".yaml", ".toml", ".ini", ".conf"];

            // Add rows for each file
            files.forEach(file => {
                const isDirectory = !file.is_file;
                let icon = "file";

                if (isDirectory) {
                    icon = "closedFolder";
                } else {
                    // Check file extension for special icons
                    const fileName = file.name.toLowerCase();
                    const fileExt = fileName.lastIndexOf('.') !== -1 ?
                        fileName.substring(fileName.lastIndexOf('.')) : "";

                    if (archiveFormats.includes(fileExt)) {
                        icon = "archive/zip";
                    } else if (scriptFiles.includes(fileExt)) {
                        icon = "code/source";
                    } else if (configFiles.includes(fileExt)) {
                        icon = "gear";
                    }
                }

                // Build full path for file actions
                let filePath;
                if (parentPath === "/" && dirName === "/") {
                    // Handle root directory special case
                    filePath = `/${file.name}`;
                } else if (parentPath === "/") {
                    filePath = `/${dirName}${sep}${file.name}`;
                } else if (dirName === "/") {
                    filePath = `${parentPath}/${file.name}`;
                } else {
                    filePath = `${parentPath}${sep}${dirName}${sep}${file.name}`;
                }

                formattedResponse.rows.push({
                    Name: {
                        plaintext: file.name,
                        cellStyle: isDirectory ? { color: "gold" } : {},
                        startIcon: icon,
                        copyIcon: true
                    },
                    Size: {
                        plaintext: file.size,
                    },
                    R: {
                      plaintext: file.permissions.readable ? "Y" : "N"
                    },
                    W: {
                      plaintext: file.permissions.writeable ? "Y" : "N"
                    },
                    X: {
                      plaintext: file.permissions.executable ? "Y" : "N"
                    },
                    Modified: {
                        plaintext: new Date(file.modify_time).toISOString(),
                    },
                    Actions: {
                        button: {
                            name: "Actions",
                            type: "menu",
                            value: [
                                {
                                    name: "View Permissions",
                                    type: "dictionary",
                                    value: file.permissions,
                                    leftColumnTitle: "Permission",
                                    rightColumnTitle: "Value",
                                    title: "File Permissions"
                                },
                                {
                                    name: "LS Path",
                                    type: "task",
                                    ui_feature: "file_browser:list",
                                    parameters: filePath,
                                    disabled: !isDirectory
                                },
                                {
                                    name: "Download File",
                                    type: "task",
                                    ui_feature: "file_browser:download",
                                    parameters: filePath,
                                    disabled: isDirectory
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