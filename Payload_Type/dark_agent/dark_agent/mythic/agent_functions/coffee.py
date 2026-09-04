from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *


class CoffeeArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass



class CoffeeCommand(CommandBase):
    cmd = "coffee"
    needs_admin = False
    help_cmd = "coffee"
    description = "Brews a cup of coffee right in your shell :-)"
    version = 1
    author = "@nicholasromanowski"
    attackmapping = []
    argument_class = CoffeeArguments
    attributes = CommandAttributes(
        builtin=False,
        load_only=True,
        suggested_command=False,
        supported_os=[SupportedOS.Linux, SupportedOS.MacOS]
    )

    async def create_go_tasking(self, taskData: PTTaskMessageAllData) -> PTTaskCreateTaskingMessageResponse:
        return PTTaskCreateTaskingMessageResponse(TaskID=taskData.Task.ID, Success=True, DisplayParams="")

