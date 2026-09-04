import json

from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class ChmodArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="mode",
                type=ParameterType.String,
                description="Octal permissions mode (e.g., 755, 644)",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=1
                )]
            ),
            CommandParameter(
                name="filepath",
                type=ParameterType.String,
                description="Path to the file or directory",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=2
                )]
            )
        ]

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        mode = dictionary_arguments.get("mode")
        filepath = dictionary_arguments.get("filepath")
        self.add_arg("name", "chmod")
        self.add_arg("mode", mode)
        self.add_arg("filepath", filepath)
        self.add_arg("bof_args", f"{mode} {filepath}")


class ChmodCommand(CommandBase):
    cmd = "chmod"
    needs_admin = False
    help_cmd = "chmod <mode> <filepath>"
    description = "Change file or directory permissions"
    version = 1
    author = "@nicholasromanowski"
    attackmapping = ["T1222.002"]
    argument_class = ChmodArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        response = PTTaskCreateTaskingMessageResponse(
            TaskID=taskData.Task.ID,
            Success=True,
            DisplayParams=taskData.args.get_arg("bof_args")
        )
        return response

    async def process_response(self, task: PTTaskMessageAllData, response: any) -> PTTaskProcessResponseMessageResponse:
        resp = PTTaskProcessResponseMessageResponse(TaskID=task.Task.ID, Success=True)
        return resp