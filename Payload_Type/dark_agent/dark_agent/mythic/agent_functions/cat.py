import json

from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class CatArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="filepath",
                type=ParameterType.String,
                description="Path to the file to read",
                parameter_group_info=[ParameterGroupInfo(
                    required=True,
                    ui_position=1
                )]
            )
        ]

    async def parse_arguments(self):
        pass

    async def parse_dictionary(self, dictionary_arguments):
        filepath = dictionary_arguments.get("filepath")
        self.add_arg("name", "cat")
        self.add_arg("filepath", filepath)
        self.add_arg("bof_args", filepath)


class CatCommand(CommandBase):
    cmd = "cat"
    needs_admin = False
    help_cmd = "cat <filepath>"
    description = "Read and display file contents"
    version = 1
    author = "@nicholasromanowski"
    attackmapping = ["T1005"]
    argument_class = CatArguments
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