import json

from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class ChownArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="owner",
                type=ParameterType.String,
                description="Owner and optional group (owner[:group], e.g., root:wheel, root, :staff)",
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
        owner = dictionary_arguments.get("owner")
        filepath = dictionary_arguments.get("filepath")
        self.add_arg("name", "chown")
        self.add_arg("owner", owner)
        self.add_arg("filepath", filepath)
        self.add_arg("bof_args", f"{owner} {filepath}")


class ChownCommand(CommandBase):
    cmd = "chown"
    needs_admin = False
    help_cmd = "chown <owner[:group]> <filepath>"
    description = "Change file or directory ownership"
    version = 1
    author = "nicholas.romanowski@servicenow.com"
    attackmapping = ["T1222.002"]
    argument_class = ChownArguments
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