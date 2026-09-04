from mythic_container.MythicCommandBase import *
import json
from mythic_container.MythicRPC import *


class UploadArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="file",
                cli_name="File",
                display_name="File",
                type=ParameterType.File,
                description="File to upload to the target",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=True,
                        group_name="Default",
                        ui_position=1
                    )
                ]
            ),
            CommandParameter(
                name="remote_path",
                cli_name="Path",
                display_name="Destination Path",
                type=ParameterType.String,
                description="Required: Path on target where to save the file.",
                parameter_group_info=[
                    ParameterGroupInfo(
                        required=True,
                        group_name="Default",
                        ui_position=2
                    )
                ]
            ),
        ]

    async def parse_arguments(self):
        if len(self.command_line) == 0:
            raise Exception("Require arguments.")
        if self.command_line[0] != "{":
            raise Exception("Require JSON blob, but got raw command line.")
        self.load_args_from_json_string(self.command_line)


class UploadCommand(CommandBase):
    cmd = "upload"
    needs_admin = False
    help_cmd = "upload (modal popup)"
    description = "Upload a file from the Mythic server to the target system."
    version = 1
    supported_ui_features = ["file_browser:upload"]
    author = "nicholas.romanowski@servicenow.com"
    argument_class = UploadArguments
    attackmapping = ["T1132", "T1030", "T1105"]
    attributes = CommandAttributes(
        suggested_command=True,
        builtin=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
        )

        file_resp = await SendMythicRPCFileSearch(
            MythicRPCFileSearchMessage(
                TaskID=taskData.Task.ID,
                AgentFileID=taskData.args.get_arg("file")
            )
        )

        if file_resp.Success:
            original_file_name = file_resp.Files[0].Filename
        else:
            raise Exception(
                "Failed to fetch uploaded file from Mythic (ID: {})".format(
                    taskData.args.get_arg("file")
                )
            )

        # Get remote path and ensure it's a simple string, not a JSON object
        remote_path = taskData.args.get_arg("remote_path")
        if isinstance(remote_path, dict) and "Path" in remote_path:
            remote_path = remote_path["Path"]
            taskData.args.add_arg("remote_path", remote_path)

        # Set the display parameters
        if remote_path:
            display_params = f"{original_file_name} to {remote_path}"
        else:
            display_params = f"{original_file_name}"

        response.DisplayParams = display_params
        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp