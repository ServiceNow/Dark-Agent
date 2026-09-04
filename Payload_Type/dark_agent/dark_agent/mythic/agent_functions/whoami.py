from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class WhoamiArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass

class WhoamiCommand(CommandBase):
    cmd = "whoami"
    needs_admin = False
    help_cmd = "whoami"
    description = "Display current user information"
    version = 1
    author = "@nicholasromanowski"
    attackmapping = []
    argument_class = WhoamiArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams="")

