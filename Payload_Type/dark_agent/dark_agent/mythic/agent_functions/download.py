from mythic_container.MythicCommandBase import *
import json


class DownloadArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="path",
                cli_name="path",
                display_name="File to download",
                type=ParameterType.String,
                description="Path to the file on target to download",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=True,
                        group_name="Default",
                        ui_position=1
                    )
                ]
            ),
            # Hidden parameters for chunk management - not shown in UI
            CommandParameter(
                name="file_id",
                type=ParameterType.String,
                description="Internal: File ID for chunk tracking",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=False,
                        ui_position=99
                    )
                ]
            ),
            CommandParameter(
                name="chunk_num",
                type=ParameterType.Number,
                description="Internal: Current chunk number",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=False,
                        ui_position=99
                    )
                ]
            ),
            CommandParameter(
                name="file_path",
                type=ParameterType.String,
                description="Internal: Full file path for continuation",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=False,
                        ui_position=99
                    )
                ]
            )
        ]

    async def parse_dictionary(self, dictionary_arguments):
        # This handles parameters passed from the file browser UI
        if "path" in dictionary_arguments:
            self.add_arg("path", dictionary_arguments["path"])
        elif "Path" in dictionary_arguments:
            self.add_arg("path", dictionary_arguments["Path"])

    async def parse_arguments(self):
        # This handles CLI commands like: download /tmp/file
        if len(self.command_line) == 0:
            raise Exception("No path specified.")

        # Direct path from command line - no JSON wrapping needed
        path = self.command_line.strip()

        # Strip quotes if present
        if (path.startswith('"') and path.endswith('"')) or (path.startswith("'") and path.endswith("'")):
            path = path[1:-1]

        self.add_arg("path", path)


class DownloadCommand(CommandBase):
    cmd = "download"
    needs_admin = False
    help_cmd = "download /path/to/file"
    description = "Download a file from the target system."
    version = 1
    supported_ui_features = ["file_browser:download"]
    author = "nicholas.romanowski@servicenow.com"
    argument_class = DownloadArguments
    attackmapping = ["T1020", "T1030", "T1041"]
    attributes = CommandAttributes(
        suggested_command=True,
        builtin=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )

        # Get the file path - this might be a Path dictionary in some UI operations
        file_path = taskData.args.get_arg("path")

        # Handle UI operations that might send a dictionary
        if isinstance(file_path, dict) and "Path" in file_path:
            file_path = file_path["Path"]
            taskData.args.remove_arg("path")
            taskData.args.add_arg("path", file_path)

        # For debugging, print what we are setting
        print(f"Download file path: {file_path}")

        response.DisplayParams = file_path
        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp