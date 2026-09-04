import json

from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class RmArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="filepath",
                type=ParameterType.String,
                description="Path to the file or directory to remove",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=1
                )]
            ),
            CommandParameter(
                name="recursive",
                type=ParameterType.Boolean,
                description="Remove directories and their contents recursively",
                default_value=False,
                parameter_group_info=[ParameterGroupInfo(
                    required=False,
                    ui_position=2
                )]
            )
        ]

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        filepath = dictionary_arguments.get("filepath")
        recursive = dictionary_arguments.get("recursive", False)
        
        self.add_arg("name", "rm")
        self.add_arg("filepath", filepath)
        self.add_arg("recursive", recursive)
        
        if recursive:
            self.add_arg("bof_args", f"{filepath} --recursive")
        else:
            self.add_arg("bof_args", filepath)


class RmCommand(CommandBase):
    cmd = "rm"
    needs_admin = False
    help_cmd = "rm <filepath> [--recursive]"
    description = "Remove files and directories"
    version = 1
    author = "@nicholasromanowski"
    attackmapping = ["T1070.004"]
    argument_class = RmArguments
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