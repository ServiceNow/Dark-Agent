from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *
import json


class IfconfigArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass


class IfconfigCommand(CommandBase):
    cmd = "ifconfig"
    needs_admin = False
    help_cmd = "ifconfig"
    description = "Display network interface information"
    version = 1
    author = "@nicholasromanowski"
    argument_class = IfconfigArguments
    attackmapping = ["T1016"]
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
    )
    browser_script = BrowserScript(
        script_name="ifconfig",
        author="@nicholasromanowski",
        for_new_ui=True
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams="")

